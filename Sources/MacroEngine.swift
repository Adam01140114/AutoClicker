import AppKit
import CoreGraphics

enum Defaults {
    static let repeatCount = "repeatCount"
    static let speed = "playbackSpeed"
    static let speedOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
}

/// Records global mouse and keyboard input with a CGEventTap and replays it with CGEvent.post.
final class MacroEngine: ObservableObject {
    enum State { case idle, recording, playing }

    @Published private(set) var state: State = .idle
    @Published private(set) var eventCount = 0
    @Published private(set) var duration: TimeInterval = 0   // length of one run at 1x
    @Published private(set) var clock: TimeInterval = 0      // live seconds while recording or playing
    @Published private(set) var round = 0                    // 1-based repeat currently playing
    @Published private(set) var rounds = 0
    @Published private(set) var notice: String?

    var hasRecording: Bool { !recording.isEmpty }

    private struct Recorded {
        var time: TimeInterval
        let event: CGEvent
    }

    /// Stamped on every event we post so the tap can tell them apart from the user's own input.
    fileprivate static let marker: Int64 = 0x4155_544F

    private static let escKeyCode: Int64 = 53

    private static let recordMask = mask([
        .mouseMoved, .scrollWheel,
        .leftMouseDown, .leftMouseUp, .leftMouseDragged,
        .rightMouseDown, .rightMouseUp, .rightMouseDragged,
        .otherMouseDown, .otherMouseUp, .otherMouseDragged,
        .keyDown, .keyUp, .flagsChanged,
    ])
    private static let playbackMask = mask([.keyDown])

    private var recording: [Recorded] = []
    private var pending: [Recorded] = []
    private var phaseStart: UInt64 = 0
    private var swallowedButtons: Set<Int64> = []
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var clockTimer: Timer?
    private let aborted = Flag()

    // MARK: Recording

    func startRecording() {
        guard state == .idle else { return }
        notice = nil
        pending = []
        swallowedButtons = []
        guard installTap(mask: Self.recordMask) else {
            notice = "Couldn't start recording. Allow AutoClicker under Accessibility and Input Monitoring, then relaunch it."
            return
        }
        state = .recording
        startClock()
    }

    private func stopRecording() {
        removeTap()
        stopClock()
        var events = pending
        pending = []
        // Drop the cursor's trip over to the Stop button: nothing after the last real action matters.
        if let last = events.lastIndex(where: { $0.event.type != .mouseMoved }) {
            events.removeSubrange((last + 1)...)
        }
        // Start the macro at its first action rather than at the moment Record was pressed.
        if let first = events.first?.time {
            for i in events.indices { events[i].time -= first }
        }
        recording = events
        eventCount = events.count
        duration = events.last?.time ?? 0
        if events.isEmpty {
            notice = "Nothing was recorded."
        }
        state = .idle
    }

    private func capture(_ type: CGEventType, _ event: CGEvent) {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        switch type {
        case .keyDown, .keyUp, .flagsChanged:
            // Keys pressed while AutoClicker itself is frontmost (e.g. ⌘. to stop) aren't part of the macro.
            if NSApp.isActive { return }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if isOverOwnWindow(event.location) {
                swallowedButtons.insert(button)
                return
            }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if swallowedButtons.remove(button) != nil { return }
        case .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            if swallowedButtons.contains(button) { return }
        default:
            if isOverOwnWindow(event.location) { return }
        }
        guard let copy = event.copy() else { return }
        pending.append(Recorded(time: seconds(since: phaseStart), event: copy))
    }

    /// Clicks on AutoClicker's own windows (Record, Stop, Settings) are controls, not part of the macro.
    private func isOverOwnWindow(_ point: CGPoint) -> Bool {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return false }
        return NSApp.windows.contains { window in
            guard window.isVisible else { return false }
            let f = window.frame
            // NSWindow frames are bottom-left origin; CGEvent locations are top-left origin.
            return CGRect(x: f.minX, y: primaryHeight - f.maxY, width: f.width, height: f.height).contains(point)
        }
    }

    // MARK: Playback

    func play() {
        guard state == .idle, !recording.isEmpty else { return }
        guard AXIsProcessTrusted() else {
            notice = "Playback needs Accessibility permission. Turn on AutoClicker in System Settings › Privacy & Security › Accessibility."
            return
        }
        notice = nil
        let defaults = UserDefaults.standard
        let repeats = max(1, defaults.integer(forKey: Defaults.repeatCount))
        let speed = min(2, max(0.5, defaults.double(forKey: Defaults.speed)))
        // Listens for Esc. If the tap can't be made, the Stop button still works.
        _ = installTap(mask: Self.playbackMask)
        aborted.set(false)
        rounds = repeats
        round = 1
        state = .playing
        startClock()

        let events = recording
        let thread = Thread { [weak self] in
            self?.runPlayback(events, repeats: repeats, speed: speed)
        }
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Runs on a background thread so timing isn't held up by the UI.
    private func runPlayback(_ events: [Recorded], repeats: Int, speed: Double) {
        var held = HeldInput()
        playing: for n in 1...repeats {
            DispatchQueue.main.async { self.round = n }
            let roundStart = DispatchTime.now().uptimeNanoseconds
            for item in events {
                let due = roundStart + UInt64(item.time / speed * 1_000_000_000)
                guard wait(until: due) else { break playing }
                held.post(item.event)
            }
        }
        // Never leave a mouse button or key stuck down, whether we finished or were stopped mid-drag.
        held.releaseAll()
        DispatchQueue.main.async { self.finishPlayback() }
    }

    /// Sleeps until `deadline` (uptime nanoseconds). Returns false if playback was stopped meanwhile.
    private func wait(until deadline: UInt64) -> Bool {
        while !aborted.isSet {
            let now = DispatchTime.now().uptimeNanoseconds
            if now >= deadline { return true }
            usleep(UInt32(min(deadline - now, 15_000_000) / 1000))
        }
        return false
    }

    private func finishPlayback() {
        removeTap()
        stopClock()
        state = .idle
    }

    // MARK: Stop

    func stop() {
        switch state {
        case .recording: stopRecording()
        case .playing: aborted.set(true)
        case .idle: break
        }
    }

    // MARK: Event tap

    private func installTap(mask: CGEventMask) -> Bool {
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                Unmanaged<MacroEngine>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.tapSource = source
        return true
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let tapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes)
        }
        tap = nil
        tapSource = nil
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        switch state {
        case .recording:
            capture(type, event)
        case .playing:
            if type == .keyDown,
               event.getIntegerValueField(.eventSourceUserData) != Self.marker,
               event.getIntegerValueField(.keyboardEventKeycode) == Self.escKeyCode {
                aborted.set(true)
            }
        case .idle:
            break
        }
    }

    private static func mask(_ types: [CGEventType]) -> CGEventMask {
        types.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }

    // MARK: Clock

    private func startClock() {
        phaseStart = DispatchTime.now().uptimeNanoseconds
        clock = 0
        clockTimer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.clock = self.seconds(since: self.phaseStart)
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func seconds(since start: UInt64) -> TimeInterval {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
    }
}

/// Posts replayed events and remembers which buttons and keys are down so they can be released.
private struct HeldInput {
    private var buttons: Set<Int64> = []
    private var keys: Set<Int64> = []
    private var modifiers: Set<Int64> = []

    private static let modifierFlags: [Int64: CGEventFlags] = [
        54: .maskCommand, 55: .maskCommand,
        56: .maskShift, 60: .maskShift,
        58: .maskAlternate, 61: .maskAlternate,
        59: .maskControl, 62: .maskControl,
        63: .maskSecondaryFn,
    ]

    mutating func post(_ original: CGEvent) {
        guard let event = original.copy() else { return }
        note(event)
        Self.send(event)
    }

    mutating func releaseAll() {
        let location = CGEvent(source: nil)?.location ?? .zero
        for button in buttons {
            let type: CGEventType = button == 0 ? .leftMouseUp : button == 1 ? .rightMouseUp : .otherMouseUp
            if let up = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
                                mouseButton: CGMouseButton(rawValue: UInt32(button)) ?? .left) {
                Self.send(up)
            }
        }
        for key in keys {
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: false) {
                up.flags = []
                Self.send(up)
            }
        }
        for key in modifiers {
            if let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: false) {
                up.type = .flagsChanged
                up.flags = []
                Self.send(up)
            }
        }
        buttons = []
        keys = []
        modifiers = []
    }

    private mutating func note(_ event: CGEvent) {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: buttons.insert(button)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp: buttons.remove(button)
        case .keyDown: keys.insert(key)
        case .keyUp: keys.remove(key)
        case .flagsChanged:
            guard let flag = Self.modifierFlags[key] else { break }
            if event.flags.contains(flag) { modifiers.insert(key) } else { modifiers.remove(key) }
        default: break
        }
    }

    private static func send(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: MacroEngine.marker)
        // Recorded events carry their original timestamps; give them a current one.
        if let now = CGEvent(source: nil)?.timestamp { event.timestamp = now }
        event.post(tap: .cghidEventTap)
    }
}

/// A Bool shared between the UI thread and the playback thread.
private final class Flag {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: Bool) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}

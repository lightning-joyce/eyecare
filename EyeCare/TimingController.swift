import AppKit
import Combine
import CoreGraphics

@MainActor
final class TimingController: ObservableObject {
    private enum Suspension: Hashable {
        case systemSleep
        case displaySleep
        case inactiveSession
        case lockedScreen
    }

    @Published private(set) var session: BreakSession?
    @Published private(set) var secondsRemaining = 0

    private let defaults: UserDefaults
    private let clockOrigin = ContinuousClock.now
    private var workTimer = WorkTimer(now: 0)
    private var suspensions: Set<Suspension> = []
    private var timer: Timer?
    private var observations: Set<AnyCancellable> = []
    private let overlay = BreakOverlay()

    var untilShortBreak: TimeInterval { workTimer.schedule.untilShortBreak }
    var untilLongBreak: TimeInterval { workTimer.schedule.untilLongBreak }
    var isAway: Bool { workTimer.awaySince != nil }
    var readingModeRemaining: TimeInterval? { workTimer.readingUntil.map { max(0, $0 - now) } }
    var canTakeBreak: Bool { workTimer.schedule.session == nil && suspensions.isEmpty }

    private var idleSeconds: TimeInterval {
        // Swift does not import kCGAnyInputEventType, a C macro cast to CGEventType.
        let anyInput = CGEventType(rawValue: UInt32.max)!
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
    }

    private var now: TimeInterval {
        let elapsed = clockOrigin.duration(to: .now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reloadPreferences()
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification, .systemSleep, suspended: true)
        observe(workspace, NSWorkspace.didWakeNotification, .systemSleep, suspended: false)
        observe(workspace, NSWorkspace.screensDidSleepNotification, .displaySleep, suspended: true)
        observe(workspace, NSWorkspace.screensDidWakeNotification, .displaySleep, suspended: false)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification, .inactiveSession, suspended: true)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, .inactiveSession, suspended: false)

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), .lockedScreen, suspended: true)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), .lockedScreen, suspended: false)

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        timer.tolerance = 0.08
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observations.removeAll()
        overlay.hide()
    }

    func reloadPreferences() {
        workTimer.schedule.longInterval = Double(BreakPreferences.hours(in: defaults) * 3600)
        workTimer.schedule.longDuration = Double(BreakPreferences.minutes(in: defaults) * 60)
        workTimer.idleThreshold = Double(BreakPreferences.idleMinutes(in: defaults) * 60)
    }

    func takeBreak(_ kind: BreakKind) {
        guard canTakeBreak else { return }
        let timestamp = now
        workTimer.update(at: timestamp, idleSeconds: 0, suspended: false, allowReminder: false)
        workTimer.startBreak(kind, at: timestamp)
        present(at: timestamp)
    }

    func endBreakEarly() {
        guard session != nil, suspensions.isEmpty else { return }
        let timestamp = now
        workTimer.endBreak(at: timestamp)
        present(at: timestamp)
    }

    func toggleReadingMode() {
        guard canTakeBreak else { return }
        let timestamp = now
        workTimer.update(at: timestamp, idleSeconds: 0, suspended: false, allowReminder: false)
        if workTimer.readingUntil == nil {
            workTimer.keepTiming(at: timestamp)
        } else {
            workTimer.endReadingMode(at: timestamp)
        }
    }

    private func update(allowReminder: Bool = true) {
        let idle = idleSeconds
        let timestamp = now
        workTimer.update(
            at: timestamp, idleSeconds: idle, suspended: !suspensions.isEmpty, allowReminder: allowReminder
        )
        present(at: timestamp)
    }

    private func present(at timestamp: TimeInterval) {
        let visibleSession = suspensions.isEmpty ? workTimer.schedule.session : nil
        let previousSession = session
        if let visibleSession {
            let remaining = Int(ceil(max(0, visibleSession.endsAt - timestamp)))
            if remaining != secondsRemaining { secondsRemaining = remaining }
        }
        if previousSession != visibleSession { session = visibleSession }
        if let visibleSession {
            if previousSession != visibleSession { overlay.show(timing: self) }
        } else if previousSession != nil {
            overlay.hide(restoreFocus: suspensions.isEmpty)
        }
    }

    private func observe(
        _ center: NotificationCenter, _ name: Notification.Name,
        _ reason: Suspension, suspended: Bool
    ) {
        center.publisher(for: name).receive(on: RunLoop.main).sink { [weak self] _ in
            self?.setSuspended(reason, suspended: suspended)
        }.store(in: &observations)
    }

    private func setSuspended(_ reason: Suspension, suspended: Bool) {
        if suspended {
            suspensions.insert(reason)
        } else {
            suspensions.remove(reason)
        }
        update(allowReminder: false)
    }
}

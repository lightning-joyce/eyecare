import Foundation

enum BreakKind: Equatable {
    case short
    case long
}

struct BreakSession: Equatable {
    let kind: BreakKind
    let duration: TimeInterval
    let endsAt: TimeInterval
}

struct BreakSchedule {
    static let shortInterval: TimeInterval = 20 * 60
    static let shortDuration: TimeInterval = 20

    var longInterval: TimeInterval = 60 * 60
    var longDuration: TimeInterval = 5 * 60

    private(set) var session: BreakSession?
    private var shortWork: TimeInterval = 0
    private var longWork: TimeInterval = 0
    private var lastUpdate: TimeInterval

    init(now: TimeInterval) {
        lastUpdate = now
    }

    var untilShortBreak: TimeInterval {
        max(0, Self.shortInterval - shortWork)
    }

    var untilLongBreak: TimeInterval {
        max(0, longInterval - longWork)
    }

    mutating func advance(to now: TimeInterval, countingWork: Bool, canStartBreak: Bool) {
        let elapsed = max(0, now - lastUpdate)
        lastUpdate = now

        if let session {
            guard now >= session.endsAt else { return }
            self.session = nil
            return
        }

        if countingWork {
            shortWork += elapsed
            longWork += elapsed
        }
        guard canStartBreak else { return }

        if untilLongBreak == 0 {
            start(.long, at: now)
        } else if untilShortBreak == 0 {
            start(.short, at: now)
        }
    }

    mutating func start(_ kind: BreakKind, at now: TimeInterval) {
        guard session == nil else { return }
        let duration = kind == .short ? Self.shortDuration : longDuration
        shortWork = 0
        if kind == .long {
            longWork = 0
        }
        lastUpdate = now
        session = BreakSession(kind: kind, duration: duration, endsAt: now + duration)
    }

    mutating func resetShortWork() {
        shortWork = 0
    }
}

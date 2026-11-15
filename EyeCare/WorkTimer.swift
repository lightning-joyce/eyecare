import Foundation

struct WorkTimer {
    static let reminderIdleGrace: TimeInterval = 30
    static let readingDuration: TimeInterval = 30 * 60

    var idleThreshold: TimeInterval = 2 * 60
    var schedule: BreakSchedule
    private(set) var awaySince: TimeInterval?
    private(set) var readingUntil: TimeInterval?
    private var idleDetectionSince: TimeInterval
    private var workSince: TimeInterval
    private var systemSuspendedSince: TimeInterval?

    init(now: TimeInterval) {
        schedule = BreakSchedule(now: now)
        idleDetectionSince = now
        workSince = now
    }

    mutating func update(
        at now: TimeInterval, idleSeconds: TimeInterval, suspended: Bool, allowReminder: Bool = true
    ) {
        if let readingUntil, now >= readingUntil {
            idleDetectionSince = readingUntil
            self.readingUntil = nil
        }

        let lastInput = now - max(0, idleSeconds)
        let reading = readingUntil != nil
        let idleSince = max(lastInput, idleDetectionSince)
        let inferredAway = !reading && now - idleSince >= idleThreshold
        let wasSuspendedSince = systemSuspendedSince
        if suspended {
            systemSuspendedSince = systemSuspendedSince ?? now
        } else {
            systemSuspendedSince = nil
        }

        if let awaySince {
            let inputSinceSuspension = wasSuspendedSince.map {
                lastInput >= $0 && idleSeconds < Self.reminderIdleGrace
            } ?? false
            if !suspended && (inputSinceSuspension || lastInput > schedule.lastUpdate) {
                let returnedAt = max(lastInput, schedule.lastUpdate)
                advance(to: returnedAt, counting: false, allowReminder: false)
                schedule.creditNaturalBreak(returnedAt - awaySince)
                self.awaySince = nil
                idleDetectionSince = returnedAt
                workSince = returnedAt
            } else {
                advance(to: now, counting: false, allowReminder: false)
                return
            }
        } else if suspended || inferredAway {
            if inferredAway {
                if schedule.session == nil {
                    // Quiet time counted while the user could still have been reading.
                    let countedIdle = max(0, schedule.lastUpdate - max(workSince, idleSince))
                    schedule.excludeIdleWork(countedIdle)
                    if idleSince > schedule.lastUpdate {
                        advance(to: idleSince, counting: true, allowReminder: false)
                    }
                }
                awaySince = idleSince
                advance(to: now, counting: false, allowReminder: false)
            } else {
                advance(to: now, counting: true, allowReminder: false)
                awaySince = now
            }
            return
        }

        let canInterrupt = reading || now - max(lastInput, idleDetectionSince) < Self.reminderIdleGrace
        advance(to: now, counting: true, allowReminder: allowReminder && canInterrupt)
    }

    mutating func startBreak(_ kind: BreakKind, at now: TimeInterval) {
        guard awaySince == nil, schedule.session == nil else { return }
        schedule.start(kind, at: now)
        workSince = now
    }

    mutating func keepTiming(at now: TimeInterval) {
        readingUntil = now + Self.readingDuration
    }

    mutating func endReadingMode(at now: TimeInterval) {
        readingUntil = nil
        idleDetectionSince = now
    }

    private mutating func advance(to now: TimeInterval, counting: Bool, allowReminder: Bool) {
        let previousBreak = schedule.session
        schedule.advance(to: now, countingWork: counting, canStartBreak: allowReminder)
        if schedule.session != previousBreak {
            workSince = now
        }
    }
}

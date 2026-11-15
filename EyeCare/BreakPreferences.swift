import Foundation

enum BreakPreferences {
    static let hoursKey = "longBreakIntervalHours"
    static let minutesKey = "longBreakDurationMinutes"
    static let idleMinutesKey = "idleThresholdMinutes"
    static let defaultHours = 1
    static let defaultMinutes = 5
    static let defaultIdleMinutes = 2
    static let hourRange = 1...24
    static let minuteRange = 1...60
    static let idleMinuteRange = 1...10

    static func hours(in defaults: UserDefaults) -> Int {
        value(for: hoursKey, in: defaults, fallback: defaultHours, range: hourRange)
    }

    static func minutes(in defaults: UserDefaults) -> Int {
        value(for: minutesKey, in: defaults, fallback: defaultMinutes, range: minuteRange)
    }

    static func idleMinutes(in defaults: UserDefaults) -> Int {
        value(for: idleMinutesKey, in: defaults, fallback: defaultIdleMinutes, range: idleMinuteRange)
    }

    private static func value(
        for key: String, in defaults: UserDefaults, fallback: Int, range: ClosedRange<Int>
    ) -> Int {
        let value = defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
        return range.contains(value) ? value : fallback
    }
}

import Foundation

enum BreakPreferences {
    static let hoursKey = "longBreakIntervalHours"
    static let minutesKey = "longBreakDurationMinutes"
    static let defaultHours = 1
    static let defaultMinutes = 5
    static let hourRange = 1...24
    static let minuteRange = 1...60

    static func hours(in defaults: UserDefaults) -> Int {
        value(for: hoursKey, in: defaults, fallback: defaultHours, range: hourRange)
    }

    static func minutes(in defaults: UserDefaults) -> Int {
        value(for: minutesKey, in: defaults, fallback: defaultMinutes, range: minuteRange)
    }

    private static func value(
        for key: String, in defaults: UserDefaults, fallback: Int, range: ClosedRange<Int>
    ) -> Int {
        let value = defaults.object(forKey: key) == nil ? fallback : defaults.integer(forKey: key)
        return range.contains(value) ? value : fallback
    }
}

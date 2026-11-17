import Foundation

struct ReadingSize: Equatable {
    static let systemLevels = 0...14
    static let finderPoints = 10...32
    static let defaultPoints = 13
    let points: Int

    init(points: Int) {
        self.points = min(Self.finderPoints.upperBound, max(Self.finderPoints.lowerBound, points))
    }

    var systemSliderValue: Int {
        // Preserve the positions used by the old 13, 15, and 16 point presets.
        switch points {
        case ..<13: return (4 * (points - 10) + 1) / 3
        case ..<16: return points - 9
        default: return 8 + (6 * (points - 16) + 8) / 16
        }
    }

    var browserPixels: Int {
        points < 16 ? 16 + 2 * (points - 13) : 24 + 2 * (points - 16)
    }
}

struct ReadingSizePreferences {
    private let pointsKey = "readingSize.points"
    var defaults: UserDefaults = .standard

    var selectedSize: ReadingSize {
        if let points = defaults.object(forKey: pointsKey) as? Int {
            return ReadingSize(points: points)
        }
        switch defaults.string(forKey: "readingSize") {
        case "large": return ReadingSize(points: 15)
        case "extraLarge": return ReadingSize(points: 16)
        default: return ReadingSize(points: ReadingSize.defaultPoints)
        }
    }

    func save(_ size: ReadingSize) {
        defaults.set(size.points, forKey: pointsKey)
    }
}

enum FinderTextSize {
    static let domain = "com.apple.finder" as CFString
    private static let standardKey = "StandardViewSettings"
    private static let filePanelKey = "FK_StandardViewSettings"
    private static let listKey = "ExtendedListViewSettingsV2"
    private static let iconKey = "IconViewSettings"
    private static let panelListKey = "FK_DefaultListViewSettingsV2"
    private static let panelIconKey = "FK_DefaultIconViewSettings"
    private static let keys = [standardKey, filePanelKey, panelListKey, panelIconKey]

    static func updated(_ current: [String: Any], size: ReadingSize) -> [String: Any] {
        var result = current
        for key in [standardKey, filePanelKey] {
            var settings = result[key] as? [String: Any] ?? [:]
            for view in [listKey, "ListViewSettings", "ColumnViewSettings", iconKey] {
                if var options = settings[view] as? [String: Any] {
                    options["textSize"] = size.points
                    settings[view] = options
                }
            }
            if !settings.isEmpty { result[key] = settings }
        }

        let panel = result[filePanelKey] as? [String: Any]
        let finder = result[standardKey] as? [String: Any]
        var list = (result[panelListKey] ?? panel?[listKey] ?? finder?[listKey]) as? [String: Any] ?? [:]
        var icons = (result[panelIconKey] ?? panel?[iconKey] ?? finder?[iconKey]) as? [String: Any] ?? [:]
        list["textSize"] = size.points
        icons["textSize"] = size.points
        result[panelListKey] = list
        result[panelIconKey] = icons
        return result
    }

    static func apply(_ size: ReadingSize) -> Bool {
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return false }
        let current = CFPreferencesCopyMultiple(
            keys as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) as? [String: Any] ?? [:]
        let changes = updated(current, size: size)
        CFPreferencesSetMultiple(changes as CFDictionary, nil, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return false }
        let stored = CFPreferencesCopyMultiple(
            keys as CFArray, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) as? [String: Any]
        return (stored?[panelListKey] as? [String: Any])?["textSize"] as? Int == size.points
            && (stored?[panelIconKey] as? [String: Any])?["textSize"] as? Int == size.points
    }
}

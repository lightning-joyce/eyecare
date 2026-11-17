import Foundation

enum ReadingSize: String, CaseIterable {
    case standard
    case large
    case extraLarge

    var systemSliderValue: Int {
        switch self {
        case .standard: return 4
        case .large: return 6
        case .extraLarge: return 8
        }
    }

    var fileListPoints: Int {
        switch self {
        case .standard: return 13
        case .large: return 15
        case .extraLarge: return 16
        }
    }

    var fileIconPoints: Int {
        self == .standard ? 12 : fileListPoints
    }

    var browserPixels: Int {
        switch self {
        case .standard: return 16
        case .large: return 20
        case .extraLarge: return 24
        }
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
                    options["textSize"] = view == iconKey ? size.fileIconPoints : size.fileListPoints
                    settings[view] = options
                }
            }
            if !settings.isEmpty { result[key] = settings }
        }

        let panel = result[filePanelKey] as? [String: Any]
        let finder = result[standardKey] as? [String: Any]
        var list = (result[panelListKey] ?? panel?[listKey] ?? finder?[listKey]) as? [String: Any] ?? [:]
        var icons = (result[panelIconKey] ?? panel?[iconKey] ?? finder?[iconKey]) as? [String: Any] ?? [:]
        list["textSize"] = size.fileListPoints
        icons["textSize"] = size.fileIconPoints
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
        return (stored?[panelListKey] as? [String: Any])?["textSize"] as? Int == size.fileListPoints
            && (stored?[panelIconKey] as? [String: Any])?["textSize"] as? Int == size.fileIconPoints
    }
}

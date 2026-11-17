import AppKit

enum BrowserTextSize: String, CaseIterable {
    case chrome = "com.google.Chrome"
    case edge = "com.microsoft.edgemac"
    case brave = "com.brave.Browser"

    var dataDirectory: String {
        switch self {
        case .chrome: return "Google/Chrome"
        case .edge: return "Microsoft Edge"
        case .brave: return "BraveSoftware/Brave-Browser"
        }
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil
    }

    func apply(_ size: ReadingSize) -> Bool {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent(dataDirectory, isDirectory: true)
        return (try? Self.apply(size, in: directory) {
            !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty
        }) == true
    }

    static func apply(_ size: ReadingSize, in directory: URL, isRunning: () -> Bool) throws -> Bool {
        let files = FileManager.default
        let lock = directory.appendingPathComponent("SingletonLock")
        func isBusy() -> Bool {
            isRunning() || (try? files.destinationOfSymbolicLink(atPath: lock.path)) != nil
        }
        guard !isBusy(), files.fileExists(atPath: directory.path) else { return false }

        let profiles = try files.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ).filter { profile in
            let name = profile.lastPathComponent
            guard name == "Default" || (name.hasPrefix("Profile ") && Int(name.dropFirst(8)) != nil) else { return false }
            let values = try profile.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            return values.isDirectory == true && values.isSymbolicLink != true
        }
        var applied = false
        for profile in profiles {
            let preferences = profile.appendingPathComponent("Preferences")
            guard files.fileExists(atPath: preferences.path) else { continue }
            let values = try preferences.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }

            let original = try Data(contentsOf: preferences)
            guard let updated = try updatedPreferences(original, points: size.browserPixels) else {
                applied = true
                continue
            }
            guard !isBusy(), try Data(contentsOf: preferences) == original, !isBusy() else { return false }
            try updated.write(to: preferences, options: .atomic)
            applied = true
        }
        return applied
    }

    private static func updatedPreferences(_ data: Data, points: Int) throws -> Data? {
        guard var preferences = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var webkit = preferences["webkit"] as? [String: Any] ?? [:]
        var webPreferences = webkit["webprefs"] as? [String: Any] ?? [:]
        guard webPreferences["default_font_size"] as? Int != points else { return nil }
        webPreferences["default_font_size"] = points
        webkit["webprefs"] = webPreferences
        preferences["webkit"] = webkit
        return try JSONSerialization.data(withJSONObject: preferences, options: [.sortedKeys, .withoutEscapingSlashes])
    }
}

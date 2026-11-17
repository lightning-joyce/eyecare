import AppKit

@MainActor
final class ReadingSizeMenu: NSObject {
    private let preferences = ReadingSizePreferences()
    private let editor = ReadingSizeEditor()
    private let pendingKey = "readingSize.pendingBrowsers"
    private lazy var item: NSMenuItem = {
        let item = NSMenuItem(title: localized("textSize.menu"), action: #selector(openEditor), keyEquivalent: "")
        item.target = self
        return item
    }()
    private var systemResult: SystemTextSize.Result?
    private var finderFailed = false

    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(browserDidQuit(_:)), name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        applyPendingBrowsers()
    }

    func makeItem() -> NSMenuItem { item }

    @objc private func openEditor() {
        var messages: [String] = []
        let canOpenSystemSettings: Bool
        switch systemResult {
        case .needsPermission:
            messages.append(localized("textSize.permission"))
            canOpenSystemSettings = false
        case .failed:
            messages.append(localized("textSize.systemFailed"))
            canOpenSystemSettings = true
        case .unavailable, .applied, nil:
            canOpenSystemSettings = false
        }
        if finderFailed { messages.append(localized("textSize.finderFailed")) }
        if !pendingBrowsers.isEmpty { messages.append(localized("textSize.browserPending")) }
        editor.show(size: preferences.selectedSize, messages: messages, canOpenSystemSettings: canOpenSystemSettings) {
            [weak self] size in self?.apply(size)
        }
    }

    private var pendingBrowsers: [String] {
        get { UserDefaults.standard.stringArray(forKey: pendingKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: pendingKey) }
    }

    private func applyPendingBrowsers() {
        guard !pendingBrowsers.isEmpty else { return }
        let size = preferences.selectedSize
        pendingBrowsers = pendingBrowsers.filter { id in
            guard let browser = BrowserTextSize(rawValue: id), browser.isInstalled else { return false }
            return !browser.apply(size)
        }
    }

    private func apply(_ size: ReadingSize) {
        item.isEnabled = false
        preferences.save(size)
        pendingBrowsers = BrowserTextSize.allCases.filter(\.isInstalled).map(\.rawValue)
        applyPendingBrowsers()
        Task {
            systemResult = await SystemTextSize.apply(size)
            finderFailed = !FinderTextSize.apply(size)
            item.isEnabled = true
        }
    }

    @objc private func browserDidQuit(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let id = app.bundleIdentifier, pendingBrowsers.contains(id) else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            applyPendingBrowsers()
        }
    }
}

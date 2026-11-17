import AppKit

@MainActor
final class ReadingSizeMenu: NSObject, NSMenuDelegate {
    private let sizeKey = "readingSize"
    private let pendingKey = "readingSize.pendingBrowsers"
    private let menu = NSMenu(title: localized("textSize.menu"))
    private var sizeItems: [NSMenuItem] = []
    private let systemStatus = NSMenuItem()
    private let finderStatus = NSMenuItem()
    private let browserStatus = NSMenuItem()
    private var systemResult: SystemTextSize.Result?
    private var finderFailed = false
    private var applying = false

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        for size in ReadingSize.allCases {
            let item = NSMenuItem(
                title: localized("textSize.\(size.rawValue)"), action: #selector(changeSize(_:)), keyEquivalent: ""
            )
            item.representedObject = size.rawValue
            item.target = self
            sizeItems.append(item)
            menu.addItem(item)
        }
        for status in [systemStatus, finderStatus, browserStatus] {
            status.isEnabled = false
            status.isHidden = true
            menu.addItem(status)
        }
        if SystemTextSize.isAvailable {
            menu.addItem(.separator())
            let settings = NSMenuItem(
                title: localized("textSize.openSystem"), action: #selector(openSystemSettings), keyEquivalent: ""
            )
            settings.target = self
            menu.addItem(settings)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(browserDidQuit(_:)), name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        applyPendingBrowsers()
    }

    func makeItem() -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        let selected = UserDefaults.standard.string(forKey: sizeKey)
        for item in sizeItems {
            item.state = (item.representedObject as? String) == selected ? .on : .off
            item.isEnabled = !applying
        }
        switch systemResult {
        case .needsPermission: show(systemStatus, "textSize.permission")
        case .failed: show(systemStatus, "textSize.systemFailed")
        case .unavailable: show(systemStatus, "textSize.systemUnavailable")
        case .applied, nil: show(systemStatus, nil)
        }
        show(finderStatus, finderFailed ? "textSize.finderFailed" : nil)
        show(browserStatus, pendingBrowsers.isEmpty ? nil : "textSize.browserPending")
    }

    private func show(_ item: NSMenuItem, _ key: String?) {
        item.isHidden = key == nil
        if let key { item.title = localized(key) }
    }

    private var pendingBrowsers: [String] {
        get { UserDefaults.standard.stringArray(forKey: pendingKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: pendingKey) }
    }

    private func applyPendingBrowsers() {
        guard let saved = UserDefaults.standard.string(forKey: sizeKey), let size = ReadingSize(rawValue: saved) else {
            return
        }
        pendingBrowsers = pendingBrowsers.filter { id in
            guard let browser = BrowserTextSize(rawValue: id), browser.isInstalled else { return false }
            return !browser.apply(size)
        }
    }

    @objc private func changeSize(_ item: NSMenuItem) {
        guard !applying, let value = item.representedObject as? String, let size = ReadingSize(rawValue: value) else {
            return
        }
        applying = true
        UserDefaults.standard.set(size.rawValue, forKey: sizeKey)
        pendingBrowsers = BrowserTextSize.allCases.filter(\.isInstalled).map(\.rawValue)
        applyPendingBrowsers()
        Task {
            systemResult = await SystemTextSize.apply(size)
            finderFailed = !FinderTextSize.apply(size)
            applying = false
        }
    }

    @objc private func openSystemSettings() { SystemTextSize.openSettings() }

    @objc private func browserDidQuit(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let id = app.bundleIdentifier, pendingBrowsers.contains(id) else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            applyPendingBrowsers()
        }
    }
}

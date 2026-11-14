import AppKit

func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

@main
@MainActor
enum EyeCare {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let timing = TimingController()
    private let settings = SettingsWindow()
    private let loginItem = LoginItem()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let shortStatus = NSMenuItem()
    private let longStatus = NSMenuItem()
    private lazy var shortBreakItem = menuItem("menu.takeShortBreak", action: #selector(takeShortBreak))
    private lazy var longBreakItem = menuItem("menu.takeLongBreak", action: #selector(takeLongBreak))

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = NSImage(systemSymbolName: "eye", accessibilityDescription: localized("app.name"))
        statusItem.button?.toolTip = localized("app.name")

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        for item in [shortStatus, longStatus] {
            item.isEnabled = false
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(shortBreakItem)
        menu.addItem(longBreakItem)
        menu.addItem(.separator())
        menu.addItem(menuItem("menu.settings", action: #selector(openSettings), key: ","))
        menu.addItem(menuItem("menu.quit", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        timing.start()
        loginItem.initialize()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        loginItem.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timing.stop()
    }

    func menuWillOpen(_ menu: NSMenu) {
        shortStatus.title = String(format: localized("menu.nextShort"), countdown(timing.untilShortBreak))
        longStatus.title = String(format: localized("menu.nextLong"), countdown(timing.untilLongBreak))
        shortBreakItem.isEnabled = timing.canTakeBreak
        longBreakItem.isEnabled = timing.canTakeBreak
    }

    private func countdown(_ interval: TimeInterval) -> String {
        Duration.seconds(Int(ceil(interval))).formatted(.time(pattern: .hourMinuteSecond))
    }

    private func menuItem(_ key: String, action: Selector, key equivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: localized(key), action: action, keyEquivalent: equivalent)
        item.target = self
        return item
    }

    @objc private func takeShortBreak() { timing.takeBreak(.short) }
    @objc private func takeLongBreak() { timing.takeBreak(.long) }
    @objc func openSettings() {
        loginItem.refresh()
        settings.show(timing: timing, loginItem: loginItem)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}

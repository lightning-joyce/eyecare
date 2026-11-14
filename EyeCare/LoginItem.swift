import AppKit
import Combine
import OSLog
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var status = SMAppService.Status.notRegistered
    @Published private(set) var failed = false

    private let service = SMAppService.mainApp
    private let defaults = UserDefaults.standard
    private let initializedKey = "launchAtLoginInitialized"
    private let logger = Logger(subsystem: "net.gltlab.eyecare", category: "LoginItem")

    var isOn: Bool {
        status == .enabled || status == .requiresApproval
    }

    func initialize() {
        refresh()
        guard !defaults.bool(forKey: initializedKey) else { return }
        if isOn {
            defaults.set(true, forKey: initializedKey)
        } else {
            setEnabled(true)
        }
    }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        failed = false
        do {
            if enabled {
                if !isOn { try service.register() }
            } else {
                if isOn { try service.unregister() }
            }
            defaults.set(true, forKey: initializedKey)
        } catch {
            failed = true
            logger.error("Could not change the login item: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    private var window: NSWindow?

    func show(timing: TimingController, loginItem: LoginItem) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 362),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = localized("menu.settings")
            window.isReleasedWhenClosed = false
            let controller = NSHostingController(rootView: SettingsView(timing: timing, loginItem: loginItem))
            controller.sizingOptions = []
            window.contentViewController = controller
            window.setContentSize(NSSize(width: 520, height: 362))
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    let timing: TimingController
    @ObservedObject var loginItem: LoginItem
    @AppStorage(BreakPreferences.hoursKey) private var hours = BreakPreferences.defaultHours
    @AppStorage(BreakPreferences.minutesKey) private var minutes = BreakPreferences.defaultMinutes
    @AppStorage(BreakPreferences.idleMinutesKey) private var idleMinutes = BreakPreferences.defaultIdleMinutes

    var body: some View {
        Form {
            Section {
                LabeledContent("settings.shortRule") {
                    Text("settings.shortDescription")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                Stepper(value: $hours, in: BreakPreferences.hourRange) {
                    LabeledContent("settings.longInterval") {
                        Text(Duration.seconds(hours * 3600).formatted(.units(allowed: [.hours], width: .wide)))
                            .monospacedDigit()
                    }
                }
                Stepper(value: $minutes, in: BreakPreferences.minuteRange) {
                    LabeledContent("settings.longDuration") {
                        Text(Duration.seconds(minutes * 60).formatted(.units(allowed: [.minutes], width: .wide)))
                            .monospacedDigit()
                    }
                }
                Stepper(value: $idleMinutes, in: BreakPreferences.idleMinuteRange) {
                    LabeledContent("settings.idleThreshold") {
                        Text(Duration.seconds(idleMinutes * 60).formatted(.units(allowed: [.minutes], width: .wide)))
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("settings.breaks")
            }

            Section {
                Toggle("settings.launchAtLogin", isOn: Binding(
                    get: { loginItem.isOn },
                    set: { loginItem.setEnabled($0) }
                ))
                if loginItem.status == .requiresApproval || loginItem.failed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loginItem.failed ? "settings.loginError" : "settings.loginApproval")
                            .foregroundStyle(.secondary)
                        Button("settings.openLoginItems") { loginItem.openSystemSettings() }
                    }
                }
            } header: {
                Text("settings.startup")
            }
        }
        .formStyle(.grouped)
        .onChange(of: hours) { _ in timing.reloadPreferences() }
        .onChange(of: minutes) { _ in timing.reloadPreferences() }
        .onChange(of: idleMinutes) { _ in timing.reloadPreferences() }
    }
}

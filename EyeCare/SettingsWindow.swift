import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    private var window: NSWindow?

    func show(timing: TimingController) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 260),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = localized("menu.settings")
            window.isReleasedWhenClosed = false
            let controller = NSHostingController(rootView: SettingsView(timing: timing))
            controller.sizingOptions = []
            window.contentViewController = controller
            window.setContentSize(NSSize(width: 520, height: 260))
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    let timing: TimingController
    @AppStorage(BreakPreferences.hoursKey) private var hours = BreakPreferences.defaultHours
    @AppStorage(BreakPreferences.minutesKey) private var minutes = BreakPreferences.defaultMinutes

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
            } header: {
                Text("settings.breaks")
            }
        }
        .formStyle(.grouped)
        .onChange(of: hours) { _ in timing.reloadPreferences() }
        .onChange(of: minutes) { _ in timing.reloadPreferences() }
    }
}

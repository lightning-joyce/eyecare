import AppKit
import SwiftUI

@MainActor
final class ReadingSizeEditor {
    private var window: NSWindow?

    func show(
        size: ReadingSize, messages: [String], canOpenSystemSettings: Bool, apply: @escaping (ReadingSize) -> Void
    ) {
        if let window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 220),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = localized("textSize.title")
        window.isReleasedWhenClosed = false
        let view = ReadingSizeForm(
            size: size, messages: messages, canOpenSystemSettings: canOpenSystemSettings,
            cancel: { [weak window] in window?.close() }
        ) { [weak window] size in
            window?.close()
            apply(size)
        }
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = []
        window.contentViewController = controller
        let sizeToFit = controller.sizeThatFits(in: NSSize(width: 440, height: 400))
        window.setContentSize(NSSize(width: 440, height: max(220, sizeToFit.height)))
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

private struct ReadingSizeForm: View {
    @State private var points: Double
    let messages: [String]
    let canOpenSystemSettings: Bool
    let cancel: () -> Void
    let apply: (ReadingSize) -> Void

    init(size: ReadingSize, messages: [String], canOpenSystemSettings: Bool,
         cancel: @escaping () -> Void, apply: @escaping (ReadingSize) -> Void) {
        self._points = State(initialValue: Double(size.points))
        self.messages = messages
        self.canOpenSystemSettings = canOpenSystemSettings
        self.cancel = cancel
        self.apply = apply
    }

    private var size: ReadingSize { ReadingSize(points: Int(points.rounded())) }

    var body: some View {
        let range = ReadingSize.finderPoints
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("textSize.finderPoints")
                Spacer()
                Text(pointLabel(size.points))
                    .font(.headline.monospacedDigit())
            }
            Slider(value: $points, in: Double(range.lowerBound)...Double(range.upperBound), step: 1) {
                Text("textSize.finderPoints")
            }
            .labelsHidden()
            .accessibilityValue(Text(pointLabel(size.points)))
            HStack {
                Text(pointLabel(range.lowerBound))
                Spacer()
                Text(pointLabel(range.upperBound))
            }
            .accessibilityHidden(true)
            .foregroundStyle(.secondary)

            Divider()

            if SystemTextSize.isAvailable {
                LabeledContent("textSize.systemLevel") {
                    Text(size.systemSliderValue.formatted())
                        .monospacedDigit()
                        .help(Text("textSize.levelHelp"))
                }
            } else {
                Text("textSize.systemUnavailable")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("textSize.browserPixels") {
                Text(String(format: localized("textSize.pixels"), size.browserPixels))
                    .monospacedDigit()
            }
            ForEach(messages, id: \.self) { message in
                Text(message)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if canOpenSystemSettings {
                Button("textSize.openSystem", action: SystemTextSize.openSettings)
            }

            HStack {
                Spacer()
                Button("textSize.cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                Button("textSize.apply") { apply(size) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func pointLabel(_ points: Int) -> String {
        String(format: localized("textSize.points"), points)
    }
}

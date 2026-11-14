import AppKit
import SwiftUI

@MainActor
final class BreakOverlay {
    private var windows: [OverlayWindow] = []
    private weak var timing: TimingController?
    private var previousApp: NSRunningApplication?
    private var screenObserver: (any NSObjectProtocol)?

    func show(timing: TimingController) {
        self.timing = timing
        previousApp = NSWorkspace.shared.frontmostApplication
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.coverScreens() }
        }
        coverScreens()
    }

    func hide(restoreFocus: Bool = false) {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        timing = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if restoreFocus, NSApp.isActive, let previousApp, previousApp != .current {
            previousApp.activate()
        }
        previousApp = nil
    }

    private func coverScreens() {
        guard let timing else { return }
        let oldWindows = windows
        let primary = NSScreen.main
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false
            )
            window.setFrame(screen.frame, display: false)
            window.level = .screenSaver
            window.isOpaque = true
            window.backgroundColor = NSColor(white: 0.08, alpha: 1)
            window.hasShadow = false
            window.hidesOnDeactivate = false
            window.isMovable = false
            window.animationBehavior = .none
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.collectionBehavior.insert(.canJoinAllApplications)
            window.contentView = NSHostingView(rootView: BreakView(timing: timing))
            window.orderFrontRegardless()
            return window
        }
        NSApp.activate(ignoringOtherApps: true)
        (windows.first(where: { $0.screen == primary }) ?? windows.first)?.makeKeyAndOrderFront(nil)
        oldWindows.forEach { $0.orderOut(nil) }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown, .keyUp, .flagsChanged:
            return
        default:
            super.sendEvent(event)
        }
    }
}

private struct BreakView: View {
    @ObservedObject var timing: TimingController

    var body: some View {
        if let session = timing.session {
            let isLong = session.kind == .long
            let countdown = Duration.seconds(timing.secondsRemaining).formatted(.time(pattern: .minuteSecond))

            VStack(spacing: 22) {
                Image(systemName: isLong ? "figure.walk" : "eye")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.mint)
                    .accessibilityHidden(true)

                Text(isLong ? "break.long.title" : "break.short.title")
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Text(isLong ? "break.long.instruction" : "break.short.instruction")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Text(countdown)
                    .font(.system(size: 74, weight: .light, design: .rounded).monospacedDigit())
                    .accessibilityLabel(Text("break.timeRemaining"))
                    .accessibilityValue(Text(countdown))

                ProgressView(value: Double(timing.secondsRemaining), total: session.duration)
                    .tint(.mint)
                    .frame(maxWidth: 240)
                    .accessibilityHidden(true)
            }
            .padding(32)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: NSColor(white: 0.08, alpha: 1)))
            .environment(\.colorScheme, .dark)
        }
    }
}

import AppKit
import ApplicationServices

@MainActor
enum SystemTextSize {
    private static let settingsBundle = "com.apple.systempreferences"
    private static let settingsURL = URL(string:
        "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?AX_FONT_SIZE"
    )!
    private static let sliderID = "AX_FONT_SIZE_SLIDER"

    enum Result {
        case applied, needsPermission, unavailable, failed
    }

    static var isAvailable: Bool {
        if #available(macOS 14, *) { return true }
        return false
    }

    static func openSettings() {
        NSWorkspace.shared.open(settingsURL)
    }

    static func apply(_ size: ReadingSize) async -> Result {
        guard isAvailable else { return .unavailable }
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
            return .needsPermission
        }
        guard NSWorkspace.shared.open(settingsURL) else { return .failed }

        var openedSheet = false
        for _ in 0..<30 {
            if let process = NSRunningApplication.runningApplications(withBundleIdentifier: settingsBundle).first {
                let app = AXUIElementCreateApplication(process.processIdentifier)
                AXUIElementSetMessagingTimeout(app, 0.25)
                for window in attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
                    if let slider = find(sliderID, in: window) {
                        guard await setSlider(slider, to: size.systemSliderValue) else { return .failed }
                        if let done = find("AX_OK", in: window) {
                            AXUIElementPerformAction(done, kAXPressAction as CFString)
                        }
                        return .applied
                    }
                    if !openedSheet, let button = find("AX_FONT_SIZE", in: window) {
                        openedSheet = AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
                    }
                    if !openedSheet, let display = find("AX_FEATURE_DISPLAY", in: window) {
                        AXUIElementPerformAction(display, kAXPressAction as CFString)
                    }
                }
            }
            try? await Task.sleep(for: .milliseconds(125))
        }
        return .failed
    }

    private static func setSlider(_ slider: AXUIElement, to target: Int) async -> Bool {
        let attributeName = kAXValueAttribute as CFString
        if let minimum = (attribute(slider, kAXMinValueAttribute) as? NSNumber)?.intValue,
           let maximum = (attribute(slider, kAXMaxValueAttribute) as? NSNumber)?.intValue,
           target < minimum || target > maximum { return false }
        if (attribute(slider, kAXValueAttribute) as? NSNumber)?.intValue == target { return true }
        if AXUIElementSetAttributeValue(slider, attributeName, NSNumber(value: target)) == .success {
            try? await Task.sleep(for: .milliseconds(125))
        }
        for _ in ReadingSize.systemLevels {
            guard let current = (attribute(slider, kAXValueAttribute) as? NSNumber)?.intValue else { return false }
            if current == target { return true }
            let action = current < target ? kAXIncrementAction : kAXDecrementAction
            guard AXUIElementPerformAction(slider, action as CFString) == .success else { return false }
            try? await Task.sleep(for: .milliseconds(125))
        }
        return (attribute(slider, kAXValueAttribute) as? NSNumber)?.intValue == target
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func find(_ id: String, in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        if attribute(element, kAXIdentifierAttribute) as? String == id { return element }
        guard depth < 16 else { return nil }
        let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.lazy.compactMap { find(id, in: $0, depth: depth + 1) }.first
    }
}

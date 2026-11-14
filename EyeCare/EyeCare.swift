import AppKit

@main
@MainActor
enum EyeCare {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

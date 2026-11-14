# EyeCare v1 requirements

1. **Automatic updates.** The app supports automatic updates. The update service may use the `gltlab.net` domain and the locally configured Wrangler CLI.
2. **20-20-20 breaks.** After 20 minutes of continuous screen use, the app must interrupt the current activity with a full-screen overlay. It prompts the user to look at an object about 6 meters (20 feet) away or farther for at least 20 seconds.
3. **Long breaks.** By default, the app shows a full-screen reminder to take a five-minute break every hour. The user can set the interval in hours and the break duration in the app.
4. **Native interface.** Use native macOS UI components.
5. **Menu bar app.** Keep the app in the macOS menu bar and hide its Dock icon.
6. **Launch at login.** Enable launch at login by default. The user can turn it off or back on in the app.

The app must support English and Simplified Chinese.

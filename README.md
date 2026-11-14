# EyeCare

EyeCare is a native macOS menu bar app for taking regular screen breaks. It supports macOS 13 and later, with English and Simplified Chinese selected through macOS language settings.

## Download

[EyeCare 1.0.0 (build 2)](https://eyecare-updates.gltlab.net/EyeCare-1.0.0-2.zip) is a universal app signed with the PURE INSIGHT TECHNOLOGY LTD Developer ID and notarized by Apple. Unzip it and move `EyeCare.app` to Applications.

ZIP SHA-256 `cf49d15f66fe338d2d2dacff7166e016868b9640e6a6eb8c15d5ce72b4dc670a`

## Run locally

Open `EyeCare.xcodeproj` in Xcode and run the EyeCare scheme. Click the eye icon in the menu bar to open Settings or preview a break. Install the app in Applications before testing its login item.

The project is generated from `project.yml`. Run `xcodegen generate` after changing the project specification or adding Swift files. Run the timing tests with:

```sh
xcodebuild -project EyeCare.xcodeproj -scheme EyeCare -destination 'platform=macOS' test
```

## Break behavior

- A 20-second distance break starts every 20 minutes of active screen time. Display sleep, system sleep, screen lock, and switching away from the macOS session pause counting. They also restart the continuous time used for distance breaks.
- A five-minute break starts after one hour of active screen time by default. Settings allows a long break interval of 1–24 hours and a duration of 1–60 minutes. Break time is excluded from both timers. A long break takes priority when both timers are due.
- The overlay covers each connected display until its countdown finishes. The app uses macOS windows for interruption and macOS continues to handle system shortcuts.
- Launch at login is enabled on first run through Service Management. Later choices in the app or in System Settings are respected.

## Automatic updates

Sparkle checks for updates in the background and downloads eligible updates to install when EyeCare quits. The menu bar also provides a manual check. The app verifies signed feeds and archives using its embedded EdDSA public key.

The production feed is hosted at [eyecare-updates.gltlab.net/appcast.xml](https://eyecare-updates.gltlab.net/appcast.xml). The signed feed in `updates/feed` is the initial empty deployment. Keep the matching private key outside the repository and retain a secure backup. The release script reads it from `~/.config/eyecare/sparkle-ed25519` by default or from the path in `EYECARE_SPARKLE_KEY_FILE`.

To publish a release:

1. Increment `CURRENT_PROJECT_VERSION` and set `MARKETING_VERSION` in `project.yml`. Regenerate the project, archive a Release build in Xcode, and export the app for Developer ID distribution. Notarize the export and staple the ticket to the app.
2. Run `scripts/prepare-update.sh /path/to/EyeCare.app`. The script checks the code signature, notarization ticket, version, and current feed, then prepares and verifies the signed feed and archive. Set `SPARKLE_TOOLS_DIR` if the tools are in a different Derived Data directory.
3. From the repository root, deploy the printed staging directory and verify that both the feed and its linked archive return HTTP 200:

   ```sh
   wrangler deploy --config updates/wrangler.jsonc --assets /absolute/path/to/staging --old-asset-ttl 86400
   ```

   The feed advertises the latest release. Keep a copy of each signed archive for rollback or support.

#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/update-feed.sh
source "$root/scripts/update-feed.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: scripts/prepare-update.sh /path/to/notarized/EyeCare.app [ASSETS_DIR]" >&2
    exit 64
fi

app="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
plist="$app/Contents/Info.plist"
expected_plist="$root/Config/Info.plist"

plist_value() {
    /usr/bin/plutil -extract "$1" raw "$2"
}

[[ "${app##*/}" == "EyeCare.app" ]]
[[ "$(plist_value CFBundleIdentifier "$plist")" == "net.gltlab.eyecare" ]]
[[ "$(plist_value SUFeedURL "$plist")" == "$feed_base/appcast.xml" ]]
[[ "$(plist_value SUPublicEDKey "$plist")" == "$(plist_value SUPublicEDKey "$expected_plist")" ]]

version="$(plist_value CFBundleShortVersionString "$plist")"
build="$(plist_value CFBundleVersion "$plist")"
check_release_numbers "$version" "$build"

/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/codesign --display --verbose=4 "$app" 2>&1 | /usr/bin/awk '
    /^Authority=Developer ID Application:/ { found = 1 }
    END { if (!found) { print "A Developer ID Application signature is required." > "/dev/stderr"; exit 1 } }
'
/usr/bin/xcrun stapler validate "$app"

check_signing_tools

mkdir -p "$root/.build"
if [[ $# -eq 2 ]]; then
    staging="$2"
    mkdir "$staging"
else
    staging="$(mktemp -d "$root/.build/updates-$build.XXXXXX")"
fi
trap 'rm -rf "$staging"' EXIT

current_feed="$staging/current.xml"
check_newer_build "$current_feed" "$build"
rm "$current_feed"

archive="$staging/EyeCare-$version-$build.zip"
/usr/bin/ditto -c -k --keepParent "$app" "$archive"
if (( $(/usr/bin/stat -f %z "$archive") > 25 * 1024 * 1024 )); then
    echo "The update archive exceeds the Cloudflare Workers static asset size limit." >&2
    exit 65
fi
"$sparkle_tools/generate_appcast" --ed-key-file "$key_file" \
    --download-url-prefix "$feed_base/" --maximum-deltas 0 "$staging"
verify_appcast "$staging/appcast.xml"
verify_update_archive "$staging/appcast.xml" "$archive" "$version" "$build"
cp "$root/updates/feed/_headers" "$staging/_headers"

trap - EXIT
printf 'Prepared signed update assets at %s\n' "$staging"

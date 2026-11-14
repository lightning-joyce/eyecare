#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
feed_base="https://eyecare-updates.gltlab.net"
sparkle_tools="${SPARKLE_TOOLS_DIR:-$root/.build/Xcode/SourcePackages/artifacts/sparkle/Sparkle/bin}"
key_file="${EYECARE_SPARKLE_KEY_FILE:-$HOME/.config/eyecare/sparkle-ed25519}"

if [[ $# != 1 ]]; then
    echo "Usage: scripts/prepare-update.sh /path/to/notarized/EyeCare.app" >&2
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
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$build" =~ ^[1-9][0-9]*$ ]]; then
    echo "Expected a version in x.y.z format and a positive integer build number." >&2
    exit 65
fi

/usr/bin/codesign --verify --deep --strict "$app"
/usr/bin/codesign --display --verbose=4 "$app" 2>&1 | /usr/bin/awk '
    /^Authority=Developer ID Application:/ { found = 1 }
    END { if (!found) { print "A Developer ID Application signature is required." > "/dev/stderr"; exit 1 } }
'
/usr/bin/xcrun stapler validate "$app"

if [[ ! -x "$sparkle_tools/generate_appcast" || ! -x "$sparkle_tools/sign_update" || ! -s "$key_file" ]]; then
    echo "Sparkle tools or the update signing key are unavailable." >&2
    exit 66
fi

mkdir -p "$root/.build"
staging="$(mktemp -d "$root/.build/updates-$build.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

current_feed="$staging/current.xml"
curl --fail --silent --show-error --max-time 25 "$feed_base/appcast.xml" -o "$current_feed"
"$sparkle_tools/sign_update" --ed-key-file "$key_file" --verify "$current_feed"
python3 - "$current_feed" "$build" <<'PY'
import sys
from xml.etree import ElementTree

namespace = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
feed = ElementTree.parse(sys.argv[1])
published = [int(v.text) for v in feed.findall(".//item/sparkle:version", namespace)]
if published and int(sys.argv[2]) <= max(published):
    sys.exit("The build number must be newer than all published builds.")
PY
rm "$current_feed"

archive="$staging/EyeCare-$version-$build.zip"
/usr/bin/ditto -c -k --keepParent "$app" "$archive"
if (( $(/usr/bin/stat -f %z "$archive") > 25 * 1024 * 1024 )); then
    echo "The update archive exceeds the Cloudflare Workers static asset size limit." >&2
    exit 65
fi
"$sparkle_tools/generate_appcast" --ed-key-file "$key_file" \
    --download-url-prefix "$feed_base/" --maximum-deltas 0 "$staging"
"$sparkle_tools/sign_update" --ed-key-file "$key_file" --verify "$staging/appcast.xml"

signature="$(/usr/bin/xmllint --xpath 'string(/rss/channel/item/enclosure/@*[local-name()="edSignature"])' "$staging/appcast.xml")"
"$sparkle_tools/sign_update" --ed-key-file "$key_file" --verify "$archive" "$signature"
cp "$root/updates/feed/_headers" "$staging/_headers"

trap - EXIT
printf 'Prepared signed update assets at %s\n' "$staging"

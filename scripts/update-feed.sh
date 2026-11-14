# Shared feed and signing helpers for the release scripts.
# shellcheck shell=bash

feed_base="https://eyecare-updates.gltlab.net"
sparkle_tools="${SPARKLE_TOOLS_DIR:-$root/.build/Xcode/SourcePackages/artifacts/sparkle/Sparkle/bin}"
key_file="${EYECARE_SPARKLE_KEY_FILE:-$HOME/.config/eyecare/sparkle-ed25519}"

check_release_numbers() {
    if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "Expected a version in x.y.z format and a positive integer build number." >&2
        return 65
    fi
}

check_signing_tools() {
    if [[ ! -x "$sparkle_tools/generate_appcast" || ! -x "$sparkle_tools/sign_update" || ! -s "$key_file" ]]; then
        echo "Sparkle tools or the update signing key are unavailable." >&2
        return 66
    fi
}

fetch_update_file() {
    curl --fail --silent --show-error --retry 2 --max-time 15 "$1" -o "$2"
}

verify_appcast() {
    "$sparkle_tools/sign_update" --ed-key-file "$key_file" --verify "$1"
}

check_newer_build() {
    local current_feed="$1" build="$2"
    fetch_update_file "$feed_base/appcast.xml" "$current_feed" &&
        verify_appcast "$current_feed" &&
        python3 - "$current_feed" "$build" <<'PY'
import sys
from xml.etree import ElementTree

namespace = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
feed = ElementTree.parse(sys.argv[1])
published = [int(v.text) for v in feed.findall(".//item/sparkle:version", namespace)]
if published and int(sys.argv[2]) <= max(published):
    sys.exit(f"Build {sys.argv[2]} must be newer than published build {max(published)}.")
PY
}

verify_update_archive() {
    local feed="$1" archive="$2" version="$3" build="$4" signature
    signature="$(python3 - "$feed" "$archive" "$version" "$build" "$feed_base" <<'PY'
from pathlib import Path
import sys
from xml.etree import ElementTree

feed_path, archive_path, version, build, feed_base = sys.argv[1:]
sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
archive = Path(archive_path)
item = ElementTree.parse(feed_path).find("./channel/item")
if (item is None or item.findtext(sparkle + "version") != build
        or item.findtext(sparkle + "shortVersionString") != version):
    sys.exit(f"Expected appcast entry for EyeCare {version} (build {build}).")

enclosure = item.find("enclosure")
if enclosure is None or enclosure.get("url") != f"{feed_base}/{archive.name}":
    sys.exit("The appcast enclosure URL does not match the release archive.")
if enclosure.get("length") != str(archive.stat().st_size):
    sys.exit("The appcast enclosure length does not match the release archive.")
signature = enclosure.get(sparkle + "edSignature")
if not signature:
    sys.exit("The appcast enclosure is missing its Sparkle signature.")
print(signature)
PY
)" && "$sparkle_tools/sign_update" --ed-key-file "$key_file" --verify "$archive" "$signature"
}

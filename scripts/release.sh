#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/update-feed.sh
source "$root/scripts/update-feed.sh"

if [[ $# -lt 2 || $# -gt 3 || ( $# -eq 3 && "$3" != --dry-run ) ]]; then
    echo "Usage: scripts/release.sh VERSION BUILD [--dry-run]" >&2
    exit 64
fi
version="$1"
build="$2"
mode="${3:-}"
team_id="${EYECARE_TEAM_ID:-Z65CXPU3NX}"
check_release_numbers "$version" "$build"
if [[ ! "$team_id" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "EYECARE_TEAM_ID must be an Apple Developer Team ID." >&2
    exit 65
fi

for tool in xcodebuild xcrun asc wrangler jq python3 curl; do
    if ! command -v "$tool" >/dev/null; then
        echo "Required tool is missing: $tool" >&2
        exit 69
    fi
done

cd "$root"
mkdir -p .build
release_dir="$(mktemp -d "$root/.build/release-$version-$build.XXXXXX")"
printf 'Release artifacts: %s\n' "$release_dir"

xcode_args=(
    -project "$root/EyeCare.xcodeproj" -scheme EyeCare
    -derivedDataPath "$root/.build/Xcode" -onlyUsePackageVersionsFromResolvedFile
)
xcodebuild "${xcode_args[@]}" -resolvePackageDependencies -quiet
check_signing_tools
check_newer_build "$release_dir/feed-before.xml" "$build"

printf '\nArchiving EyeCare %s (build %s) for Intel and Apple silicon\n' "$version" "$build"
archive="$release_dir/EyeCare.xcarchive"
xcodebuild "${xcode_args[@]}" archive -configuration Release -destination 'generic/platform=macOS' \
    -archivePath "$archive" "MARKETING_VERSION=$version" "CURRENT_PROJECT_VERSION=$build" \
    ONLY_ACTIVE_ARCH=NO -quiet

printf '\nExporting with Xcode automatic Developer ID signing\n'
export_options="$release_dir/ExportOptions.plist"
cat > "$export_options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$team_id</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$archive" -exportPath "$release_dir/export" \
    -exportOptionsPlist "$export_options" -allowProvisioningUpdates

app="$release_dir/export/EyeCare.app"
plist="$app/Contents/Info.plist"
[[ "$(plutil -extract CFBundleShortVersionString raw "$plist")" == "$version" ]]
[[ "$(plutil -extract CFBundleVersion raw "$plist")" == "$build" ]]
xcrun lipo "$app/Contents/MacOS/EyeCare" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$app"
signing_details="$(codesign --display --verbose=4 "$app" 2>&1)"
if [[ "$signing_details" != *$'\nAuthority=Developer ID Application: '* ||
      "$signing_details" != *$'\nTimestamp='* ||
      "$signing_details"$'\n' != *$'\nTeamIdentifier='"$team_id"$'\n'* ]]; then
    echo "Expected a timestamped Developer ID Application signature for $team_id." >&2
    exit 65
fi

printf '\nSubmitting the Developer ID build to Apple for notarization\n'
notary_zip="$release_dir/EyeCare-notary.zip"
ditto -c -k --keepParent "$app" "$notary_zip"
asc notarization submit --file "$notary_zip" --output json > "$release_dir/notary-submission.json"
submission_id="$(jq -er '.data.id | select(type == "string" and length > 0)' "$release_dir/notary-submission.json")"
printf 'Notarization submission: %s\n' "$submission_id"

# Apple's ticket can become available while the status API still returns an error.
deadline=$((SECONDS + 3600))
last_status=""
while (( SECONDS < deadline )); do
    status=""
    if asc notarization status --id "$submission_id" --output json \
        > "$release_dir/notary-status.json" 2> "$release_dir/notary-status.stderr"; then
        status="$(jq -er '.data.attributes.status' "$release_dir/notary-status.json")"
    fi
    case "$status" in
        Invalid|Rejected)
            echo "Apple rejected notarization for $submission_id." >&2
            asc notarization log --id "$submission_id" --output json > "$release_dir/notary-log.json" || true
            exit 1
            ;;
        Accepted|"")
            if xcrun stapler staple "$app" > "$release_dir/stapler.log" 2>&1; then
                break
            fi
            ;;
    esac
    reported_status="${status:-Status unavailable}"
    if [[ "$reported_status" != "$last_status" ]]; then
        printf 'Notarization: %s\n' "$reported_status"
        last_status="$reported_status"
    fi
    sleep 15
done
if ! xcrun stapler validate "$app"; then
    echo "No valid notarization ticket after waiting for $submission_id. See $release_dir." >&2
    exit 1
fi
spctl --assess --type execute -vv "$app"

printf '\nPreparing and signing the Sparkle update\n'
assets="$release_dir/assets"
"$root/scripts/prepare-update.sh" "$app" "$assets"
archive_name="EyeCare-$version-$build.zip"

wrangler_args=(deploy --config "$root/updates/wrangler.jsonc" --assets "$assets" --old-asset-ttl 86400)
wrangler "${wrangler_args[@]}" --dry-run
if [[ "$mode" == --dry-run ]]; then
    printf 'Dry run complete. The signed update is ready at %s\n' "$assets"
    exit 0
fi

# Recheck the live release after building and notarizing, before changing the feed.
check_newer_build "$release_dir/feed-before-deploy.xml" "$build"
printf '\nPublishing the update to %s\n' "$feed_base"
wrangler "${wrangler_args[@]}"

printf '\nVerifying the published appcast and ZIP\n'
online_dir="$release_dir/online"
mkdir "$online_dir"
for attempt in {1..6}; do
    if fetch_update_file "$feed_base/appcast.xml" "$online_dir/appcast.xml" &&
        cmp -s "$assets/appcast.xml" "$online_dir/appcast.xml" &&
        verify_appcast "$online_dir/appcast.xml" &&
        fetch_update_file "$feed_base/$archive_name" "$online_dir/$archive_name" &&
        cmp -s "$assets/$archive_name" "$online_dir/$archive_name" &&
        verify_update_archive "$online_dir/appcast.xml" "$online_dir/$archive_name" "$version" "$build"; then
        printf 'Published EyeCare %s (build %s)\n%s/%s\n' "$version" "$build" "$feed_base" "$archive_name"
        shasum -a 256 "$online_dir/$archive_name"
        exit 0
    fi
    if (( attempt < 6 )); then sleep 5; fi
done
echo "The deployment completed, but online verification failed. See $release_dir." >&2
exit 1

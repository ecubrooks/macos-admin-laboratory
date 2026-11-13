#!/bin/bash
# Name:        build-app.sh
# Purpose:     Builds the AI Control macOS menu bar application.
#              Creates the app bundle, icon, and required resources.
#
# How it works:
#   1) Runs Swift tests and builds the AI Control release.
#   2) Copies the executable and resources into the app bundle.
#   3) Generates the app icon and Info.plist.
#   4) Signs the app bundle using the configured signing identity.
#
# Notes:
#   - Requires macOS and Xcode command line tools.
#   - Uses ad hoc signing when CODE_SIGN_IDENTITY is not provided.
#   - Output is saved to the build directory.
#
# Date: October 13th, 2026
# ------------------------------------------------------------------------------
# Exits if a command fails or an undefined variable is used
set -euo pipefail

# Sets the working directory to the project root
cd "$(dirname "$0")/.."

# Checks that the script is running on macOS
if [[ "$(uname -s)" != Darwin ]]; then
    echo "Build this native app on macOS with Xcode command line tools installed." >&2
    exit 1
fi

# Version metadata; increment BUILD_NUMBER for each distributed build.
app_version="${APP_VERSION:-1.1}"
build_number="${BUILD_NUMBER:-2}"
[[ "$app_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "Invalid APP_VERSION" >&2; exit 1; }
[[ "$build_number" =~ ^[1-9][0-9]*$ ]] || { echo "Invalid BUILD_NUMBER" >&2; exit 1; }

# Runs Swift tests before building the app
swift test

# Builds the release version of AI Control and defines the paths used to create the app bundle
swift build -c release -Xswiftc -debug-prefix-map -Xswiftc "$PWD=/AIControl"
binary_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/build/AI Control.app"
logo_source="$PWD/Sources/AIControl/Resources/AI Control logo.png"
iconset_dir="$(mktemp -d)/AI Control logo.iconset"

# Removes temporary icon files when the script exits
trap 'rm -rf "$(dirname "$iconset_dir")"' EXIT

# Creates the app bundle folders and copies the required files
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/AIControl" "$app_dir/Contents/MacOS/AIControl"
cp Sources/AIControlCore/Resources/features.json "$app_dir/Contents/Resources/features.json"

# Creates icons in the sizes required by macOS and converts the images into the app icon file
mkdir -p "$iconset_dir"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$logo_source" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -z "$double_size" "$double_size" "$logo_source" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_dir" -o "$app_dir/Contents/Resources/AI Control logo.icns"

# Creates the app information and configures it as a menu bar app
cat > "$app_dir/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>AI Control</string>
<key>CFBundleDisplayName</key><string>AI Control</string>
<key>CFBundleIdentifier</key><string>io.github.aicontrol.app</string>
<key>CFBundleExecutable</key><string>AIControl</string>
<key>CFBundleIconFile</key><string>AI Control logo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$app_version</string>
<key>CFBundleVersion</key><string>$build_number</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

# Remove debug symbols and local build paths.
xcrun strip -S "$app_dir/Contents/MacOS/AIControl"

# Signs the app bundle with the supplied identity or ad hoc signing
plutil -lint "$app_dir/Contents/Info.plist"
if [[ "${CODE_SIGN_IDENTITY:--}" == "-" ]]; then
    codesign --force --sign - "$app_dir"
else
    codesign --force --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$app_dir"
fi
codesign --verify --deep --strict --verbose=2 "$app_dir"

# Displays the completed app bundle location
echo "Built: $app_dir"

exit

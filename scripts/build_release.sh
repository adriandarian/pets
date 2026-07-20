#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Pets"
BUNDLE_ID="local.pets.Pets"
VERSION_FILE="VERSION"
BUILD_NUMBER_FILE="BUILD_NUMBER"
VERSION="$(tr -d '[:space:]' <"${VERSION_FILE}")"
BUILD_NUMBER="$(tr -d '[:space:]' <"${BUILD_NUMBER_FILE}")"
RELEASE_GIFT_TIER="$(./scripts/release_gift_tier.sh "${VERSION}")"
BUNDLE_PATH="dist/${APP_NAME}.app"
EXECUTABLE_PATH="${BUNDLE_PATH}/Contents/MacOS/${APP_NAME}"
PLIST_PATH="${BUNDLE_PATH}/Contents/Info.plist"
RESOURCE_BUNDLE_NAME="${APP_NAME}_PetsCore.bundle"
RESOURCE_BUNDLE_SOURCE=".build/release/${RESOURCE_BUNDLE_NAME}"
RESOURCE_BUNDLE_DESTINATION="${BUNDLE_PATH}/Contents/Resources/${RESOURCE_BUNDLE_NAME}"
ARCHIVE_PATH="dist/${APP_NAME}-${VERSION}.zip"

if [[ ! "${VERSION}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "VERSION must contain only dot-separated numbers." >&2
  exit 1
fi

if [[ ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
  echo "BUILD_NUMBER must be a positive integer." >&2
  exit 1
fi

swift build -c release

rm -rf "${BUNDLE_PATH}"
rm -f "${ARCHIVE_PATH}"
mkdir -p "${BUNDLE_PATH}/Contents/MacOS" "${BUNDLE_PATH}/Contents/Resources"
cp ".build/release/${APP_NAME}" "${EXECUTABLE_PATH}"
cp -R "${RESOURCE_BUNDLE_SOURCE}" "${RESOURCE_BUNDLE_DESTINATION}"

cat >"${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>PetsReleaseGiftTier</key>
  <string>${RELEASE_GIFT_TIER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "${BUNDLE_PATH}"

COPYFILE_DISABLE=1 /usr/bin/ditto \
  -c -k --sequesterRsrc --keepParent \
  "${BUNDLE_PATH}" "${ARCHIVE_PATH}"

echo "Built unsigned GitHub release artifact: ${ARCHIVE_PATH}"

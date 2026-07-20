#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PRODUCT_NAME="Pets"
APP_NAME="Pets Dev"
BUNDLE_ID="local.pets.Pets.dev"
VERSION_FILE="VERSION"
BUILD_NUMBER_FILE="BUILD_NUMBER"
VERSION="$(tr -d '[:space:]' <"${VERSION_FILE}")"
BUILD_NUMBER="$(tr -d '[:space:]' <"${BUILD_NUMBER_FILE}")"
BUILD_PATH=".build/development"
BUNDLE_PATH="dist/${APP_NAME}.app"
EXECUTABLE_PATH="${BUNDLE_PATH}/Contents/MacOS/${APP_NAME}"
PLIST_PATH="${BUNDLE_PATH}/Contents/Info.plist"
RESOURCE_BUNDLE_NAME="${PRODUCT_NAME}_PetsCore.bundle"
RESOURCE_BUNDLE_SOURCE="${BUILD_PATH}/debug/${RESOURCE_BUNDLE_NAME}"

if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  pkill -x "${APP_NAME}"
fi

swift build \
  --scratch-path "${BUILD_PATH}" \
  -Xswiftc -DPETS_DEVELOPMENT

rm -rf "${BUNDLE_PATH}"
mkdir -p "${BUNDLE_PATH}/Contents/MacOS"
cp "${BUILD_PATH}/debug/${PRODUCT_NAME}" "${EXECUTABLE_PATH}"
cp -R "${RESOURCE_BUNDLE_SOURCE}" "${BUNDLE_PATH}/${RESOURCE_BUNDLE_NAME}"

cat >"${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/open -n "${BUNDLE_PATH}"

if [[ "${1:-}" == "--verify" ]]; then
  for _ in {1..20}; do
    if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
      echo "Launched ${BUNDLE_PATH}"
      exit 0
    fi
    sleep 0.25
  done

  echo "Failed to verify ${APP_NAME} launch" >&2
  exit 1
fi

echo "Launched ${BUNDLE_PATH}"

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Pets"
BUNDLE_ID="local.pets.Pets"
BUNDLE_PATH="dist/${APP_NAME}.app"
EXECUTABLE_PATH="${BUNDLE_PATH}/Contents/MacOS/${APP_NAME}"
PLIST_PATH="${BUNDLE_PATH}/Contents/Info.plist"

if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  pkill -x "${APP_NAME}"
fi

swift build

rm -rf "${BUNDLE_PATH}"
mkdir -p "${BUNDLE_PATH}/Contents/MacOS"
cp ".build/debug/${APP_NAME}" "${EXECUTABLE_PATH}"

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
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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

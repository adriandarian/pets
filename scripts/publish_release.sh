#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' <VERSION)"
TAG="v${VERSION}"
ARCHIVE_PATH="dist/Pets-${VERSION}.zip"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit the release changes before publishing ${TAG}." >&2
  exit 1
fi

if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "Authenticate GitHub CLI before publishing: gh auth login" >&2
  exit 1
fi

if gh release view "${TAG}" >/dev/null 2>&1; then
  echo "GitHub release ${TAG} already exists." >&2
  exit 1
fi

./scripts/check.sh
./scripts/build_release.sh

gh release create "${TAG}" "${ARCHIVE_PATH}" \
  --target "$(git rev-parse HEAD)" \
  --title "Pets ${VERSION}" \
  --generate-notes \
  --latest

echo "Published ${TAG}: https://github.com/adriandarian/pets/releases/tag/${TAG}"

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-}"
OVERRIDES_FILE="${2:-RELEASE_GIFT_OVERRIDES}"

if [[ ! "${VERSION}" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "Release gift version must contain only dot-separated numbers." >&2
  exit 1
fi

if [[ ! -r "${OVERRIDES_FILE}" ]]; then
  echo "Missing release gift overrides file: ${OVERRIDES_FILE}" >&2
  exit 1
fi

awk -v target_version="${VERSION}" '
  BEGIN {
    selected_tier = "routine"
    invalid = 0
  }

  {
    sub(/#.*/, "")
    gsub(/^[[:space:]]+|[[:space:]]+$/, "")
    if ($0 == "") {
      next
    }

    if (NF != 2 || $1 !~ /^[0-9]+([.][0-9]+)*$/ || $2 !~ /^(major|anniversary)$/) {
      print "Invalid release gift override: " $0 > "/dev/stderr"
      invalid = 1
      next
    }

    if (seen[$1]++) {
      print "Duplicate release gift override for version " $1 > "/dev/stderr"
      invalid = 1
      next
    }

    if ($1 == target_version) {
      selected_tier = $2
    }
  }

  END {
    if (invalid) {
      exit 1
    }
    print selected_tier
  }
' "${OVERRIDES_FILE}"

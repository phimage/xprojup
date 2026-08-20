#!/usr/bin/env bash
#
# extract-recommended.sh
#
# Dumps the default build settings that Xcode bakes into new projects, taken from
# `Base_ProjectSettings.xctemplate/TemplateInfo.plist` inside the installed Xcode.
# This is the authoritative superset of the settings shown by Xcode's
# "Update to recommended settings" prompt.
#
# Use it when a new Xcode ships: run the script, diff its output against the
# `warns(...)` map in `Sources/xprojup/main.swift`, and add any new keys under a
# new version threshold.
#
# Usage:
#   scripts/extract-recommended.sh                 # SharedSettings as JSON
#   scripts/extract-recommended.sh --all           # SharedSettings + Debug/Release configs
#   scripts/extract-recommended.sh --keys          # just the setting keys, one per line
#   DEVELOPER_DIR=/Applications/Xcode-16.app/Contents/Developer scripts/extract-recommended.sh
#
set -euo pipefail

# --- Resolve the Xcode developer directory (must be a full Xcode, not CommandLineTools) ---
resolve_developer_dir() {
  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    echo "$DEVELOPER_DIR"; return 0
  fi
  local selected
  selected="$(xcode-select -p 2>/dev/null || true)"
  if [[ "$selected" == *"/Xcode"*".app/"* || "$selected" == *"/Xcode.app/"* ]]; then
    echo "$selected"; return 0
  fi
  # xcode-select points at CommandLineTools (or nothing): fall back to /Applications.
  local candidate="/Applications/Xcode.app/Contents/Developer"
  if [[ -d "$candidate" ]]; then
    echo "$candidate"; return 0
  fi
  echo "ERROR: could not locate a full Xcode. Set DEVELOPER_DIR or run xcode-select -s." >&2
  return 1
}

DEV_DIR="$(resolve_developer_dir)"
TEMPLATE="$DEV_DIR/Library/Xcode/Templates/Project Templates/Base/Base_ProjectSettings.xctemplate/TemplateInfo.plist"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: template not found: $TEMPLATE" >&2
  exit 1
fi

# Report which Xcode we read from (stderr, so stdout stays pure data).
XCODE_APP="${DEV_DIR%/Contents/Developer}"
XCODE_VER="$(defaults read "$XCODE_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")"
echo "# Xcode $XCODE_VER — $TEMPLATE" >&2

MODE="${1:-shared}"

python3 - "$TEMPLATE" "$MODE" <<'PY'
import json, plistlib, sys

template, mode = sys.argv[1], sys.argv[2]
with open(template, "rb") as f:
    info = plistlib.load(f)

project = info.get("Project", {})
shared = project.get("SharedSettings", {})
configs = project.get("Configurations", {})

if mode == "--keys":
    for key in sorted(shared):
        print(key)
elif mode == "--all":
    out = {"SharedSettings": shared, "Configurations": configs}
    print(json.dumps(out, indent=2, sort_keys=True))
else:  # default: shared settings only
    print(json.dumps(shared, indent=2, sort_keys=True))
PY

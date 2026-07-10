#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODEGEN="$ROOT/.tools/xcodegen-2.45.4/xcodegen/bin/xcodegen"

if [[ ! -x "$XCODEGEN" ]]; then
  echo "Missing local XcodeGen binary: $XCODEGEN" >&2
  echo "Download it from https://github.com/yonaskolb/XcodeGen/releases" >&2
  exit 1
fi

cd "$ROOT"
"$XCODEGEN" generate

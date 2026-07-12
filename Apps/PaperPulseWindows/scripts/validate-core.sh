#!/usr/bin/env bash
set -euo pipefail

configuration="${1:-Debug}"

case "$configuration" in
  Debug|Release) ;;
  *)
    echo "Configuration must be Debug or Release." >&2
    exit 2
    ;;
esac

if ! command -v dotnet >/dev/null 2>&1; then
  echo "Install .NET SDK 10.0.301 and add it to PATH before running this script." >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
solution="$root/PaperPulse.Core.sln"

dotnet restore "$solution"
dotnet build "$solution" --configuration "$configuration" --no-restore
dotnet test "$solution" --configuration "$configuration" --no-build

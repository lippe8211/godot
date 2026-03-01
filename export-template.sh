#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./export-template.sh <ios|tvos> [--dry-run]

Builds Godot export templates and generates the platform zip used in
Export preset `custom_template/debug` and `custom_template/release`.

Examples:
  ./export-template.sh ios
  ./export-template.sh tvos
  ./export-template.sh tvos --dry-run
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PLATFORM="$1"
shift || true

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift || true
fi

if [[ $# -ne 0 ]]; then
  echo "Error: unexpected arguments." >&2
  usage
  exit 1
fi

if [[ "$PLATFORM" != "ios" && "$PLATFORM" != "tvos" ]]; then
  echo "Error: platform must be 'ios' or 'tvos'." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: this script currently supports macOS hosts only." >&2
  exit 1
fi

SCONS_CMD=()
if command -v scons >/dev/null 2>&1; then
  SCONS_CMD=(scons)
elif /Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -m SCons --version >/dev/null 2>&1; then
  SCONS_CMD=(/Library/Frameworks/Python.framework/Versions/3.11/bin/python3 -m SCons)
elif command -v python3 >/dev/null 2>&1 && python3 -m SCons --version >/dev/null 2>&1; then
  SCONS_CMD=(python3 -m SCons)
else
  echo "Error: SCons not found. Install with: python3 -m pip install --user scons" >&2
  exit 1
fi

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || true)"
if [[ -z "$JOBS" ]]; then
  JOBS=1
fi

LOCK_DIR=".export-template.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Error: another export-template.sh process is already running in this checkout." >&2
  exit 1
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

run_scons() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "==> ${SCONS_CMD[*]} $* -j$JOBS -n"
    "${SCONS_CMD[@]}" "$@" -j"$JOBS" -n
  else
    echo "==> ${SCONS_CMD[*]} $* -j$JOBS"
    "${SCONS_CMD[@]}" "$@" -j"$JOBS"
  fi
}

# Device templates.
run_scons "platform=${PLATFORM}" target=template_debug arch=arm64
run_scons "platform=${PLATFORM}" target=template_release arch=arm64

# Simulator templates (both simulator archs).
run_scons "platform=${PLATFORM}" target=template_debug arch=arm64 simulator=yes
run_scons "platform=${PLATFORM}" target=template_release arch=arm64 simulator=yes
run_scons "platform=${PLATFORM}" target=template_debug arch=x86_64 simulator=yes
run_scons "platform=${PLATFORM}" target=template_release arch=x86_64 simulator=yes

# Build Apple embedded export zip.
run_scons "platform=${PLATFORM}" target=template_release arch=arm64 generate_bundle=yes

if [[ $DRY_RUN -eq 0 ]]; then
  echo ""
  echo "Generated template zip(s):"
  ls -1 "bin/"*"${PLATFORM}"*.zip 2>/dev/null || echo "No zip found in bin/. Build may have failed."
  echo ""
  echo "Set this zip in Godot Export preset:"
  echo "  custom_template/debug   = <zip path>"
  echo "  custom_template/release = <zip path>"
fi

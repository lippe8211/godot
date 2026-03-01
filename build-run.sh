#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./build-run.sh
  ./build-run.sh /absolute/or/relative/project_path
  ./build-run.sh --path /absolute/or/relative/project_path

Builds Godot editor for macOS (dev build) and runs it.
If a project path is provided, it is passed to Godot via --path.
USAGE
}

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH

PROJECT_PATH=""
case "${1:-}" in
  "" ) ;;
  -h|--help)
    usage
    exit 0
    ;;
  --path)
    if [[ $# -ne 2 ]]; then
      echo "Error: --path requires exactly one argument." >&2
      usage
      exit 1
    fi
    PROJECT_PATH="$2"
    ;;
  *)
    if [[ $# -ne 1 ]]; then
      echo "Error: unexpected arguments." >&2
      usage
      exit 1
    fi
    PROJECT_PATH="$1"
    ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: build-run.sh currently targets macOS only." >&2
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Error: unsupported architecture '$ARCH'." >&2
    exit 1
    ;;
esac

JOBS="$(sysctl -n hw.ncpu 2>/dev/null || true)"
if [[ -z "$JOBS" ]]; then
  JOBS=1
fi

SCONS_CMD=()
if command -v scons >/dev/null 2>&1; then
  SCONS_CMD=(scons)
else
  PYTHON_CANDIDATES=(
    "$(command -v python3 2>/dev/null || true)"
    "/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
    "/opt/homebrew/bin/python3"
    "/usr/local/bin/python3"
    "/usr/bin/python3"
  )

  for py in "${PYTHON_CANDIDATES[@]}"; do
    if [[ -n "$py" && -x "$py" ]] && "$py" -m SCons --version >/dev/null 2>&1; then
      SCONS_CMD=("$py" -m SCons)
      break
    fi
  done

  if [[ ${#SCONS_CMD[@]} -eq 0 ]]; then
    echo "Error: SCons not found. Install with: python3 -m pip install --user scons" >&2
    exit 1
  fi
fi

LOCK_DIR=".build-run.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Error: another build-run.sh process appears to be running in this checkout." >&2
  exit 1
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

echo "Building Godot editor (platform=macos, target=editor, dev_build=yes, arch=$ARCH)..."
BUILD_LOG=".build-run.scons.log"
set +e
"${SCONS_CMD[@]}" platform=macos target=editor dev_build=yes arch="$ARCH" -j"$JOBS" 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ $BUILD_STATUS -ne 0 ]]; then
  if rg -q "MoltenVK SDK installation directory not found" "$BUILD_LOG"; then
    echo "MoltenVK SDK not found. Retrying build with vulkan=no..."
    "${SCONS_CMD[@]}" platform=macos target=editor dev_build=yes arch="$ARCH" vulkan=no -j"$JOBS"
  else
    exit "$BUILD_STATUS"
  fi
fi

BIN="bin/godot.macos.editor.dev.${ARCH}"
if [[ ! -x "$BIN" ]]; then
  echo "Error: expected binary '$BIN' was not produced." >&2
  exit 1
fi

if [[ -n "$PROJECT_PATH" ]]; then
  echo "Running: $BIN --path $PROJECT_PATH"
  "$BIN" --path "$PROJECT_PATH"
  exit $?
fi

echo "Running: $BIN"
"$BIN"

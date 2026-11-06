#!/usr/bin/env bash
# download-tiktok.sh — download one TikTok reference video with
# omniget-cli (see TIKTOK_METHOD.md). Installs the tool first if it is
# missing (install-omniget.sh).
#
# Usage: bash download-tiktok.sh <TikTok URL> [output-dir]
#   default output dir: ~/workspace/downloads/omniget/tiktok
#
# IRON RULE (Muse VMs): the machine has no direct egress, so the
# download MUST go through the proxy from the environment
# (--proxy "$HTTPS_PROXY"). Without it every fetch fails and the error
# misleadingly claims the extractor is broken. On a machine with direct
# internet and no proxy env vars, the flag is simply omitted.
#
# Prints the downloaded file path on the last line, then the
# prepare-reference.sh command to archive it as a Hypit project.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
URL="${1:-}"
OUT="${2:-$HOME/workspace/downloads/omniget/tiktok}"
[ -n "$URL" ] || { echo "Usage: $0 <TikTok URL> [output-dir]" >&2; exit 2; }

CLI="$HOME/workspace/tools/omniget/omniget-cli"
if [ ! -x "$CLI" ]; then
  echo "omniget-cli not found — installing it first..."
  bash "$SCRIPT_DIR/install-omniget.sh"
fi

PROXY_ARGS=()
if [ -n "${HTTPS_PROXY:-}" ]; then PROXY_ARGS=(--proxy "$HTTPS_PROXY");
elif [ -n "${https_proxy:-}" ]; then PROXY_ARGS=(--proxy "$https_proxy"); fi

mkdir -p "$OUT"

echo "--- info (title / author / duration) ---"
"$CLI" info "${PROXY_ARGS[@]}" "$URL" || echo "(info failed — trying the download anyway)"

BEFORE="$(mktemp)"; ls -A "$OUT" > "$BEFORE" || true
echo "--- download ---"
if ! "$CLI" download "${PROXY_ARGS[@]}" -o "$OUT" "$URL"; then
  echo "download failed once — retrying the same command (TikTok is usually stable; a single retry is the agreed rule)..."
  "$CLI" download "${PROXY_ARGS[@]}" -o "$OUT" "$URL"
fi

NEW_FILE="$(comm -13 <(sort "$BEFORE") <(ls -A "$OUT" | sort) | head -1 || true)"
rm -f "$BEFORE"
if [ -z "$NEW_FILE" ]; then
  # fall back to the newest media file in the output dir
  NEW_FILE="$(ls -t "$OUT" | head -1 || true)"
fi
[ -n "$NEW_FILE" ] && [ -f "$OUT/$NEW_FILE" ] || { echo "ERROR: no file landed in $OUT" >&2; exit 1; }
FILE="$OUT/$NEW_FILE"

if command -v ffprobe >/dev/null 2>&1; then
  echo "--- verify ---"
  ffprobe -v error -show_entries format=duration -show_entries stream=codec_name,width,height -of compact "$FILE" || true
fi

echo "Downloaded: $FILE"
echo "Next (archive + frame evidence):"
echo "  bash \"$SCRIPT_DIR/prepare-reference.sh\" \"$FILE\" <english-project-name>"

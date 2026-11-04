#!/usr/bin/env bash
# prepare-reference.sh — archive a downloaded TikTok reference video into a
# standard decomposition project and generate the frame evidence.
#
# Usage: bash prepare-reference.sh <downloaded-file.mp4> <project-name>
#   e.g. bash prepare-reference.sh ~/Downloads/video.mp4 agris-street-run
#
# Creates ~/workspace/hypit-projects/<project-name>/ with:
#   references/source.mp4   the original, renamed
#   references/PROBE.txt    specs + visual-change candidates + audio levels
#   evidence/tiles/         0.5s time-labeled frame grids (hypit media tiles)
#
# The download itself is a browser step (see TIKTOK_METHOD.md); this script
# covers everything after the file lands on disk.
set -Eeuo pipefail

SRC="${1:-}"
NAME="${2:-}"
[ -n "$SRC" ] && [ -n "$NAME" ] || { echo "Usage: $0 <downloaded-file.mp4> <project-name>" >&2; exit 2; }
[ -f "$SRC" ] || { echo "ERROR: file not found: $SRC" >&2; exit 1; }

HYPIT=""
if [ -x "$HOME/.local/share/hypit-cli/bin/hypit" ]; then
  HYPIT="$HOME/.local/share/hypit-cli/bin/hypit"
elif command -v hypit >/dev/null 2>&1; then
  HYPIT="$(command -v hypit)"
else
  echo "ERROR: hypit CLI not found — run the kit's install.sh first." >&2; exit 1
fi
command -v ffprobe >/dev/null 2>&1 || { echo "ERROR: ffprobe (ffmpeg) is required." >&2; exit 1; }

PROJECT="$HOME/workspace/hypit-projects/$NAME"
mkdir -p "$PROJECT/references" "$PROJECT/evidence"
cp "$SRC" "$PROJECT/references/source.mp4"
VIDEO="$PROJECT/references/source.mp4"

DURATION="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")"
# tiles sampling must end slightly BEFORE the total duration, otherwise hypit
# errors with "no video frame exists at or after <duration>".
END="$(python3 -c "print(max(0.1, float('$DURATION') - 0.1))")"

{
  echo "file: references/source.mp4"
  echo "downloaded_from: $SRC"
  echo "--- probe ---"
  "$HYPIT" media probe "$VIDEO"
  echo "--- boundaries (visual-change candidates, NOT shot labels) ---"
  "$HYPIT" media boundaries "$VIDEO" 2>&1 | tail -25
  echo "--- audio levels ---"
  ffmpeg -i "$VIDEO" -vn -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume' || true
} > "$PROJECT/references/PROBE.txt"

"$HYPIT" media tiles "$VIDEO" --start 0 --end "$END" --every 0.5 --cell 320 --columns 5 --to "$PROJECT/evidence/tiles"

echo "Project ready: $PROJECT"
echo "  references/source.mp4  (${DURATION}s)"
echo "  references/PROBE.txt"
echo "  evidence/tiles/ (0.5s grids)"
echo "Next: watch the tiles in full, then write references/TIMELINE.md + ANALYSIS.md (see TIKTOK_METHOD.md)."

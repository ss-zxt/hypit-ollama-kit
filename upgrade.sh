#!/usr/bin/env bash
# upgrade.sh — move the kit's pinned versions to the latest OFFICIAL releases.
#
#   ./upgrade.sh --check   report only: current pins vs latest official versions
#   ./upgrade.sh           apply: refresh pins + checksums in versions.env,
#                          re-run install.sh --force, then verify (incl. inference)
#
# Why upgrades are NOT silent/automatic: a major Hypit or Ollama bump can change
# CLI flags or the runtime profile format and break a working setup. This script
# makes upgrading deliberate and safe:
#   * versions.env is backed up first (versions.env.bak-<timestamp>)
#   * install.sh keeps the previous ~/ollama as ~/ollama.backup-<timestamp>
#   * rollback: cp the backup back to versions.env, then ./install.sh --force
#
# The model (qwen3:1.7b) is a floating tag: "upgrading" it means re-pulling the
# tag to refresh its digest, which this script always does. Switching to a
# different model tag stays a manual versions.env edit (OLLAMA_MODEL).
# The Hypit skill is not separately pinned — install.sh --force re-fetches it
# from the hypit-ai/hypit repo, so it follows the repo's latest.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
[ -f "$SCRIPT_DIR/versions.env" ] && . "$SCRIPT_DIR/versions.env"
HYPIT_VERSION="${HYPIT_VERSION:-0.3.1}"
OLLAMA_VERSION="${OLLAMA_VERSION:-0.40.14}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:1.7b}"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1
[ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ] && { sed -n '2,25p' "$0"; exit 0; }

info() { printf '  %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

echo "== Checking official latest versions =="
LATEST_HYPIT="$(npm view @hypit/hypit version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
[ -n "$LATEST_HYPIT" ] || die "could not read the latest @hypit/hypit version from the npm registry"

LATEST_OLLAMA="$(curl -fsSL --max-time 30 https://api.github.com/repos/ollama/ollama/releases/latest 2>/dev/null \
  | grep -oE '"tag_name": *"v?[0-9]+\.[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
if [ -z "$LATEST_OLLAMA" ]; then
  # Fallback: follow the /releases/latest redirect and parse the tag from it.
  LATEST_OLLAMA="$(curl -fsSI --max-time 30 https://github.com/ollama/ollama/releases/latest 2>/dev/null \
    | grep -i '^location:' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi
[ -n "$LATEST_OLLAMA" ] || die "could not read the latest Ollama release from GitHub"

printf '  %-10s %-14s %-14s %s\n' "component" "pinned" "latest" "status"
printf '  %-10s %-14s %-14s %s\n' "hypit" "$HYPIT_VERSION" "$LATEST_HYPIT" \
  "$([ "$HYPIT_VERSION" = "$LATEST_HYPIT" ] && echo 'up to date' || echo 'UPDATE AVAILABLE')"
printf '  %-10s %-14s %-14s %s\n' "ollama" "$OLLAMA_VERSION" "$LATEST_OLLAMA" \
  "$([ "$OLLAMA_VERSION" = "$LATEST_OLLAMA" ] && echo 'up to date' || echo 'UPDATE AVAILABLE')"
printf '  %-10s %-14s %-14s %s\n' "model" "$OLLAMA_MODEL" "(tag)" "re-pull refreshes the digest"

CHANGED=0
[ "$LATEST_HYPIT" != "$HYPIT_VERSION" ] && CHANGED=1
[ "$LATEST_OLLAMA" != "$OLLAMA_VERSION" ] && CHANGED=1

if [ "$CHECK_ONLY" -eq 1 ]; then
  [ "$CHANGED" -eq 1 ] && info "updates available — run ./upgrade.sh to apply" || info "everything is already at the latest official version"
  exit 0
fi

if [ "$CHANGED" -eq 0 ]; then
  echo "== Pins already latest — refreshing the model tag only =="
  OLLAMA_BIN="$HOME/ollama/bin/ollama"
  [ -x "$OLLAMA_BIN" ] || die "ollama not installed yet; run ./install.sh first"
  OLLAMA_HOST=127.0.0.1:11434 "$OLLAMA_BIN" pull "$OLLAMA_MODEL"
  bash "$SCRIPT_DIR/verify.sh"
  echo "Done: model refreshed, versions unchanged."
  exit 0
fi

echo "== Applying upgrade =="
TS="$(date +%Y%m%d%H%M%S)"
cp "$SCRIPT_DIR/versions.env" "$SCRIPT_DIR/versions.env.bak-$TS"
info "backed up versions.env -> versions.env.bak-$TS"

NEW_OLLAMA_SHA=""
if ! curl -fsSL --max-time 60 "https://github.com/ollama/ollama/releases/download/v${LATEST_OLLAMA}/sha256sum.txt" \
    | awk '$2 ~ /ollama-linux-amd64\.tar\.zst$/ {print $1; exit}' > /tmp/.ollama-sha.$$ 2>/dev/null; then
  : # leave empty; install.sh will fetch and verify against the release file itself
fi
NEW_OLLAMA_SHA="$(cat /tmp/.ollama-sha.$$ 2>/dev/null || true)"; rm -f /tmp/.ollama-sha.$$
NEW_HYPIT_INTEGRITY="$(npm view "@hypit/hypit@$LATEST_HYPIT" dist.integrity 2>/dev/null || true)"

{
  printf '# Pinned versions for the Hypit + Ollama replication kit.\n'
  printf '# Updated by upgrade.sh on %s (previous pins: versions.env.bak-%s).\n' "$(date -Iseconds)" "$TS"
  printf 'HYPIT_VERSION=%s\n' "$LATEST_HYPIT"
  printf 'OLLAMA_VERSION=%s\n' "$LATEST_OLLAMA"
  printf 'OLLAMA_MODEL=%s\n' "$OLLAMA_MODEL"
  printf 'OLLAMA_ARCHIVE_SHA256=%s\n' "$NEW_OLLAMA_SHA"
  printf 'HYPIT_NPM_INTEGRITY=%s\n' "$NEW_HYPIT_INTEGRITY"
} > "$SCRIPT_DIR/versions.env"
info "versions.env now pins hypit $LATEST_HYPIT / ollama $LATEST_OLLAMA"

if bash "$SCRIPT_DIR/install.sh" --force; then
  echo "Upgrade complete and verified."
else
  echo "ERROR: upgrade failed during install/verify." >&2
  echo "Rollback: cp \"$SCRIPT_DIR/versions.env.bak-$TS\" \"$SCRIPT_DIR/versions.env\" && \"$SCRIPT_DIR/install.sh\" --force" >&2
  echo "(the previous ~/ollama was also kept as ~/ollama.backup-* by install.sh)" >&2
  exit 1
fi

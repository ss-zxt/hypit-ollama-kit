#!/usr/bin/env bash
# install-omniget.sh — install the TikTok capture tool used by
# TIKTOK_METHOD.md: omniget-cli (OpenSelena/omniget, GPL-3.0) plus a
# pinned yt-dlp engine, both from their official GitHub releases and
# SHA-256 verified (pins live in ../versions.env).
#
# Layout (matches the verified setup on the author's machine):
#   ~/workspace/tools/omniget/omniget-cli                    the CLI binary
#   ~/.local/share/com.openselena.omniget/bin/yt-dlp         the engine
# The yt-dlp copy is placed by hand on purpose: omniget's own
# auto-download of the engine fails on Muse VMs (verified 2026-11-05),
# so do not delete that file on upgrades/reinstalls.
#
# Idempotent: components already present at the pinned version are
# skipped. Pass --force to reinstall anyway.
# Usage: bash install-omniget.sh [--force]
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIT_DIR="$(dirname "$SCRIPT_DIR")"
[ -f "$KIT_DIR/versions.env" ] && . "$KIT_DIR/versions.env"
OMNIGET_VERSION="${OMNIGET_VERSION:-0.14.0}"
OMNIGET_CLI_SHA256="${OMNIGET_CLI_SHA256:-ec29439b1928c0871592f5c10b758349dad01a5411950e00e46313f6617d0de4}"
YTDLP_VERSION="${YTDLP_VERSION:-2026.10.26}"
YTDLP_SHA256="${YTDLP_SHA256:-e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3}"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

[ "$(uname -m)" = "x86_64" ] || { echo "ERROR: this installer pins the x86_64 Linux build of omniget-cli." >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl is required." >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: sha256sum is required." >&2; exit 1; }

# Muse VMs have no direct egress: downloads must go through the proxy
# from the environment when one is set. Never print the proxy value.
PROXY_ARGS=()
if [ -n "${HTTPS_PROXY:-}" ]; then PROXY_ARGS=(--proxy "$HTTPS_PROXY");
elif [ -n "${https_proxy:-}" ]; then PROXY_ARGS=(--proxy "$https_proxy"); fi

fetch() { curl -fsSL --max-time 300 "${PROXY_ARGS[@]}" -o "$2" "$1"; }
verify_sha() { # file expected
  local got
  got="$(sha256sum "$1" | awk '{print $1}')"
  [ "$got" = "$2" ] || { echo "ERROR: SHA-256 mismatch for $1 (got $got)" >&2; exit 1; }
}

TOOLS_DIR="$HOME/workspace/tools/omniget"
CLI="$TOOLS_DIR/omniget-cli"
YTDLP_DIR="$HOME/.local/share/com.openselena.omniget/bin"
YTDLP="$YTDLP_DIR/yt-dlp"
mkdir -p "$TOOLS_DIR" "$YTDLP_DIR"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- omniget-cli
if [ -x "$CLI" ] && [ "$FORCE" -eq 0 ]; then
  echo "omniget-cli already installed (skip; --force to reinstall): $CLI"
else
  ASSET="omniget-cli-${OMNIGET_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
  URL="https://github.com/OpenSelena/omniget/releases/download/v${OMNIGET_VERSION}/${ASSET}"
  echo "Downloading omniget-cli v${OMNIGET_VERSION} from the official release..."
  fetch "$URL" "$TMP/cli.tar.gz"
  verify_sha "$TMP/cli.tar.gz" "$OMNIGET_CLI_SHA256"
  tar -xzf "$TMP/cli.tar.gz" -C "$TMP"
  [ -f "$TMP/omniget-cli" ] || { echo "ERROR: archive did not contain omniget-cli." >&2; exit 1; }
  install -m 0755 "$TMP/omniget-cli" "$CLI"
  echo "installed: $CLI"
fi
"$CLI" --help >/dev/null 2>&1 || { echo "ERROR: omniget-cli does not run." >&2; exit 1; }
# NOTE: the binary self-reports version 0.1.0 regardless of the release
# version (upstream internal version lag) — harmless, do not "fix" it.

# ---------------------------------------------------------------- yt-dlp engine
if [ -x "$YTDLP" ] && [ "$FORCE" -eq 0 ] && [ "$("$YTDLP" --version 2>/dev/null || true)" = "$YTDLP_VERSION" ]; then
  echo "yt-dlp $YTDLP_VERSION already in place (skip): $YTDLP"
else
  URL="https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp"
  echo "Downloading yt-dlp ${YTDLP_VERSION} (official zipapp)..."
  fetch "$URL" "$TMP/yt-dlp"
  verify_sha "$TMP/yt-dlp" "$YTDLP_SHA256"
  install -m 0755 "$TMP/yt-dlp" "$YTDLP"
  echo "installed: $YTDLP"
fi
[ "$("$YTDLP" --version)" = "$YTDLP_VERSION" ] || { echo "ERROR: yt-dlp version mismatch." >&2; exit 1; }

echo "Done. Capture a TikTok reference with:"
echo "  bash \"$SCRIPT_DIR/download-tiktok.sh\" \"<TikTok URL>\""

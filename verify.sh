#!/usr/bin/env bash
# verify.sh — check the Hypit + Ollama stack end to end.
# Default run includes a tiny qwen3 inference smoke test (think:false);
# pass --no-smoke to skip inference. Exit code 0 only if every check passes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
[ -f "$SCRIPT_DIR/versions.env" ] && . "$SCRIPT_DIR/versions.env"
HYPIT_VERSION="${HYPIT_VERSION:-0.3.1}"
OLLAMA_VERSION="${OLLAMA_VERSION:-0.40.14}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:1.7b}"
# Auto-selected installs record the resolved tag; follow it when pinned as auto.
if [ "$OLLAMA_MODEL" = "auto" ]; then
  RESOLVED_FILE="$HOME/.local/state/muse-hypit-ollama-kit/resolved-model.txt"
  if [ -f "$RESOLVED_FILE" ]; then
    OLLAMA_MODEL="$(head -1 "$RESOLVED_FILE")"
  else
    echo "  [FAIL] OLLAMA_MODEL=auto but no resolved model recorded — run install.sh --auto-model first"
    exit 1
  fi
fi
API="http://127.0.0.1:11434"

SMOKE=1
[ "${1:-}" = "--no-smoke" ] && SMOKE=0

FAIL=0
ok()   { printf '  [OK]   %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; FAIL=1; }
note() { printf '  [..]   %s\n' "$*"; }

HYPIT_BIN="$HOME/.local/share/hypit-cli/bin/hypit"
[ -x "$HYPIT_BIN" ] || HYPIT_BIN="$(command -v hypit || true)"
if [ -n "${HYPIT_BIN:-}" ] && [ -x "$HYPIT_BIN" ]; then
  V="$("$HYPIT_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
  [ "$V" = "$HYPIT_VERSION" ] && ok "hypit CLI $V" || note "hypit CLI present (version '${V:-unknown}', expected $HYPIT_VERSION)"
else
  bad "hypit CLI not found"
fi

[ -f "$HOME/.agents/skills/hypit/SKILL.md" ] && ok "hypit skill present" || bad "hypit skill missing (~/.agents/skills/hypit)"

command -v ffmpeg >/dev/null 2>&1 && ok "ffmpeg $(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')" || bad "ffmpeg missing"

ls -d "$HOME/.cache/puppeteer/chrome/"linux-* >/dev/null 2>&1 \
  && ok "capture Chrome present" || note "capture Chrome cache not found (run: hypit capture install-browser)"
ls "$HOME/.cache/hypit/html-rasterizer/chrome/chrome-headless-shell/"linux-*/chrome-headless-shell-linux64/chrome-headless-shell >/dev/null 2>&1 \
  && ok "renderer headless shell present" || note "renderer headless shell not found (run: hypit programs prepare)"

OLLAMA_BIN="$HOME/ollama/bin/ollama"
if [ -x "$OLLAMA_BIN" ]; then
  V="$("$OLLAMA_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
  [ "$V" = "$OLLAMA_VERSION" ] && ok "ollama binary $V" || note "ollama binary present (version '${V:-unknown}', expected $OLLAMA_VERSION)"
else
  bad "ollama binary missing (~/ollama/bin/ollama)"
fi

if VER="$(curl -fsS --max-time 5 "$API/api/version" 2>/dev/null)"; then
  ok "ollama API up: $VER"
else
  bad "ollama API not responding on $API (try: bash setup-ollama-service.sh)"
fi

if curl -fsS --max-time 5 "$API/api/tags" 2>/dev/null | OLLAMA_MODEL="$OLLAMA_MODEL" python3 -c 'import sys, json, os; names = [m.get("name") for m in json.load(sys.stdin).get("models", [])]; sys.exit(0 if os.environ["OLLAMA_MODEL"] in names else 1)' 2>/dev/null; then
  ok "model $OLLAMA_MODEL present"
else
  bad "model $OLLAMA_MODEL not in /api/tags (try: ollama pull $OLLAMA_MODEL)"
fi

OMNIGET_VERSION="${OMNIGET_VERSION:-0.14.0}"
YTDLP_VERSION="${YTDLP_VERSION:-2026.10.26}"
OMNIGET_CLI="$HOME/workspace/tools/omniget/omniget-cli"
if [ -x "$OMNIGET_CLI" ] && "$OMNIGET_CLI" --help >/dev/null 2>&1; then
  ok "omniget-cli present (TikTok capture, release $OMNIGET_VERSION)"
else
  note "omniget-cli not found (run: bash tiktok/install-omniget.sh)"
fi
YTDLP_BIN="$HOME/.local/share/com.openselena.omniget/bin/yt-dlp"
if [ -x "$YTDLP_BIN" ]; then
  V="$("$YTDLP_BIN" --version 2>/dev/null || true)"
  [ "$V" = "$YTDLP_VERSION" ] && ok "yt-dlp $V (omniget engine)" || note "yt-dlp present (version '${V:-unknown}', expected $YTDLP_VERSION)"
else
  note "yt-dlp engine not found (run: bash tiktok/install-omniget.sh)"
fi

if [ "$SMOKE" -eq 1 ] && [ "$FAIL" -eq 0 ]; then
  RESP="$(curl -fsS --max-time 120 -X POST "$API/api/generate" -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":\"请用中文一句话介绍你自己。\",\"stream\":false,\"think\":false,\"options\":{\"num_predict\":64}}" 2>/dev/null || true)"
  if [ -n "$RESP" ]; then
    LINE="$(printf '%s' "$RESP" | python3 -c 'import sys,json; print((json.load(sys.stdin).get("response") or "").strip().splitlines()[0][:80])' 2>/dev/null || true)"
    [ -n "$LINE" ] && ok "inference smoke test: $LINE" || bad "inference returned an empty response"
  else
    bad "inference smoke test failed (no response from /api/generate)"
  fi
fi

if [ "$FAIL" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "SOME CHECKS FAILED — see [FAIL] lines above"
  exit 1
fi

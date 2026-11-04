#!/usr/bin/env bash
# install.sh — one-click installer for the Hypit + Ollama + qwen3 stack.
#
# What it installs (everything under $HOME so it survives VM replacement):
#   1. Hypit skill            -> ~/.agents/skills/hypit        (npx skills add hypit-ai/hypit)
#   2. Hypit CLI (pinned)     -> ~/.local/share/hypit-cli      (npm @hypit/hypit, symlinked to ~/.local/bin/hypit)
#   3. Hypit browsers         -> ~/.cache/puppeteer + ~/.cache/hypit (capture Chrome + renderer headless shell)
#   4. Ollama (pinned)        -> ~/ollama                      (official GitHub release tar.zst, sha256-verified)
#   5. Ollama systemd service -> /etc/systemd/system/ollama.service (proxy env baked in; re-run after VM restart)
#   6. Model qwen3:1.7b       -> ~/.ollama/models              (ollama pull)
#
# Idempotent: re-running skips whatever is already in place and only restores
# what is missing (e.g. the systemd unit after a VM replacement).
#
# Usage:
#   ./install.sh [--skip-browsers] [--skip-model] [--skip-smoke]
#                [--auto-model] [--check-only] [--force] [--help]
# --auto-model: instead of the pinned OLLAMA_MODEL, pick the qwen3 size that
# fits this machine (see select-model.sh). Same effect as OLLAMA_MODEL=auto
# in versions.env. The resolved tag is recorded in the state dir so
# verify.sh / upgrade.sh follow it.
# Env overrides: HYPIT_VERSION, OLLAMA_VERSION, OLLAMA_MODEL (see versions.env).
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
[ -f "$SCRIPT_DIR/versions.env" ] && . "$SCRIPT_DIR/versions.env"
HYPIT_VERSION="${HYPIT_VERSION:-0.3.1}"
OLLAMA_VERSION="${OLLAMA_VERSION:-0.40.14}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen3:1.7b}"
OLLAMA_ARCHIVE_SHA256="${OLLAMA_ARCHIVE_SHA256:-}"

SKILL_DIR="$HOME/.agents/skills/hypit"
HYPIT_PREFIX="$HOME/.local/share/hypit-cli"
BIN_DIR="$HOME/.local/bin"
OLLAMA_DIR="$HOME/ollama"
OLLAMA_DIST="$HOME/ollama-dist"
STATE_DIR="$HOME/.local/state/muse-hypit-ollama-kit"
OLLAMA_BASE_URL="https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}"
OLLAMA_ARCHIVE="ollama-linux-amd64.tar.zst"
OLLAMA_HOST_URL="http://127.0.0.1:11434"

SKIP_BROWSERS=0; SKIP_MODEL=0; SKIP_SMOKE=0; CHECK_ONLY=0; FORCE=0; AUTO_MODEL=0
for arg in "$@"; do
  case "$arg" in
    --skip-browsers) SKIP_BROWSERS=1 ;;
    --skip-model)    SKIP_MODEL=1 ;;
    --skip-smoke)    SKIP_SMOKE=1 ;;
    --auto-model)    AUTO_MODEL=1 ;;
    --check-only)    CHECK_ONLY=1 ;;
    --force)         FORCE=1 ;;
    --help|-h)
      sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

log()  { printf '\n== %s ==\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '  WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 && SUDO="sudo"
fi

# ---------------------------------------------------------------- preflight
log "Preflight"
[ "$(uname -s)" = "Linux" ] || die "This kit is built for Linux (tested on Ubuntu 24.04 Muse VMs)."
case "$(uname -m)" in
  x86_64|amd64) info "architecture: x86_64" ;;
  *) die "Unsupported architecture $(uname -m): the pinned Ollama asset is linux-amd64." ;;
esac
# Detected-environment report (this is what --check-only exists for).
OS_PRETTY="$(grep -E '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || true)"
RAM_GB_DETECTED=$(( ( $(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null || echo 0) + 524288 ) / 1048576 ))
info "OS: ${OS_PRETTY:-unknown Linux}, kernel $(uname -r)"
info "RAM: ${RAM_GB_DETECTED} GB total; systemd: $([ -d /run/systemd/system ] && echo present || echo 'absent (nohup fallback will be used)')"
for cmd in curl tar python3 node npm npx; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
done
# Hypit 0.3.1 declares engines node >= 22.15.0 — enforce it up front instead of
# failing mysteriously later.
node -e 'const v=process.versions.node.split(".").map(Number); const ok=v[0]>22||(v[0]===22&&(v[1]>15||(v[1]===15&&v[2]>=0))); process.exit(ok?0:1)' \
  || die "Node.js >= 22.15.0 is required by Hypit (found $(node --version)). Install a newer Node first."
info "node $(node --version), npm $(npm --version), python3 present"

if ! command -v ffmpeg >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1 && { [ -n "$SUDO" ] || [ "$(id -u)" -eq 0 ]; }; then
    info "ffmpeg missing — installing via apt-get"
    $SUDO apt-get update -qq && $SUDO apt-get install -y -qq ffmpeg >/dev/null
  fi
fi
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg is required by Hypit and could not be installed automatically."
info "ffmpeg: $(ffmpeg -version 2>/dev/null | head -1 | cut -d' ' -f1-3)"

AVAIL_KB="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
if [ "${AVAIL_KB:-0}" -lt 6500000 ]; then
  warn "Less than ~6.5 GB free under $HOME (archive 1.5G + binaries 2.4G + model 1.4G + browsers ~0.7G)."
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  info "check-only: preflight passed, nothing installed."
  exit 0
fi

mkdir -p "$BIN_DIR" "$HYPIT_PREFIX" "$OLLAMA_DIST" "$STATE_DIR"

# ------------------------------------------------- model selection (optional)
if [ "$AUTO_MODEL" -eq 1 ] || [ "$OLLAMA_MODEL" = "auto" ]; then
  log "Model selection (auto, by machine specs)"
  OLLAMA_MODEL="$(bash "$SCRIPT_DIR/select-model.sh")"
  printf '%s\n' "$OLLAMA_MODEL" > "$STATE_DIR/resolved-model.txt"
  info "selected $OLLAMA_MODEL for this machine (recorded in $STATE_DIR/resolved-model.txt)"
fi

# ---------------------------------------------------------------- Hypit skill
log "Hypit skill"
if [ -f "$SKILL_DIR/SKILL.md" ] && [ "$FORCE" -eq 0 ]; then
  info "already installed at $SKILL_DIR (skip; --force to reinstall)"
else
  npx -y skills add hypit-ai/hypit -g -y
  [ -f "$SKILL_DIR/SKILL.md" ] || die "skill install did not produce $SKILL_DIR/SKILL.md"
  info "installed to $SKILL_DIR"
fi

# ---------------------------------------------------------------- Hypit CLI
log "Hypit CLI @hypit/hypit@$HYPIT_VERSION"
HYPIT_BIN="$HYPIT_PREFIX/bin/hypit"
CUR_HYPIT_VER=""
[ -x "$HYPIT_BIN" ] && CUR_HYPIT_VER="$("$HYPIT_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
if [ "$CUR_HYPIT_VER" = "$HYPIT_VERSION" ] && [ "$FORCE" -eq 0 ]; then
  info "already at $CUR_HYPIT_VER (skip)"
else
  npm install --global --prefix "$HYPIT_PREFIX" "@hypit/hypit@$HYPIT_VERSION"
  [ -x "$HYPIT_BIN" ] || die "npm install did not produce $HYPIT_BIN"
fi
ln -sf "$HYPIT_BIN" "$BIN_DIR/hypit"
info "hypit -> $BIN_DIR/hypit (version $("$BIN_DIR/hypit" --version 2>/dev/null | tail -1))"

# ---------------------------------------------------------------- Hypit browsers
if [ "$SKIP_BROWSERS" -eq 0 ]; then
  log "Hypit browsers (capture Chrome + renderer headless shell)"
  "$BIN_DIR/hypit" capture install-browser
  # `hypit programs prepare` only runs inside a Hypit project with a selected
  # Runtime profile (it errors out in a bare directory), so drive it through
  # the bundled minimal smoke project, copied to the state dir to keep the
  # kit folder clean.
  SMOKE_DIR="$STATE_DIR/smoke-project"
  rm -rf "$SMOKE_DIR"
  cp -r "$SCRIPT_DIR/smoke-project" "$SMOKE_DIR"
  ( cd "$SMOKE_DIR" \
      && "$BIN_DIR/hypit" runtime use ./hypit.runtime.json >/dev/null \
      && "$BIN_DIR/hypit" programs prepare )
  info "browser caches: ~/.cache/puppeteer, ~/.cache/hypit"
else
  info "skipping browsers (--skip-browsers)"
fi

# ---------------------------------------------------------------- Ollama binary
log "Ollama $OLLAMA_VERSION"
OLLAMA_BIN="$OLLAMA_DIR/bin/ollama"
CUR_OLLAMA_VER=""
[ -x "$OLLAMA_BIN" ] && CUR_OLLAMA_VER="$("$OLLAMA_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || true)"
if [ "$CUR_OLLAMA_VER" = "$OLLAMA_VERSION" ] && [ "$FORCE" -eq 0 ]; then
  info "already at $CUR_OLLAMA_VER in $OLLAMA_DIR (skip download)"
else
  ARCHIVE_PATH="$OLLAMA_DIST/ollama-linux-amd64-v${OLLAMA_VERSION}.tar.zst"
  if [ ! -f "$ARCHIVE_PATH" ]; then
    info "downloading $OLLAMA_BASE_URL/$OLLAMA_ARCHIVE (~1.5 GB)"
    curl -fL --retry 3 --retry-delay 2 -C - -o "$ARCHIVE_PATH" "$OLLAMA_BASE_URL/$OLLAMA_ARCHIVE"
  fi
  # Verify against the official release checksum file (fall back to pinned hash).
  EXPECTED="$OLLAMA_ARCHIVE_SHA256"
  if curl -fsSL --max-time 60 -o "$OLLAMA_DIST/sha256sum-v${OLLAMA_VERSION}.txt" "$OLLAMA_BASE_URL/sha256sum.txt" 2>/dev/null; then
    FOUND="$(awk '$2 ~ /ollama-linux-amd64\.tar\.zst$/ {print $1; exit}' "$OLLAMA_DIST/sha256sum-v${OLLAMA_VERSION}.txt" || true)"
    [ -n "$FOUND" ] && EXPECTED="$FOUND"
  fi
  if [ -n "$EXPECTED" ]; then
    ACTUAL="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
    [ "$ACTUAL" = "$EXPECTED" ] || die "sha256 mismatch for $ARCHIVE_PATH (got $ACTUAL, want $EXPECTED). Delete the file and re-run."
    info "sha256 verified: $ACTUAL"
  else
    warn "no checksum available; continuing unverified"
  fi
  STAGE="$(mktemp -d "$HOME/.ollama-extract.XXXXXX")"
  info "extracting to staging dir"
  if tar --zstd -tf "$ARCHIVE_PATH" >/dev/null 2>&1; then
    tar --zstd -xf "$ARCHIVE_PATH" -C "$STAGE"
  elif command -v zstd >/dev/null 2>&1; then
    zstd -dc "$ARCHIVE_PATH" | tar -xf - -C "$STAGE"
  else
    python3 -c 'import zstandard' 2>/dev/null || \
      python3 -m pip install --user --break-system-packages -q zstandard || \
      die "need zstd, tar --zstd, or the python 'zstandard' module to extract the Ollama archive"
    python3 "$SCRIPT_DIR/extract_zst.py" "$ARCHIVE_PATH" "$STAGE"
  fi
  [ -x "$STAGE/bin/ollama" ] || { rm -rf "$STAGE"; die "archive did not contain bin/ollama"; }
  if [ -d "$OLLAMA_DIR" ]; then
    mv "$OLLAMA_DIR" "$OLLAMA_DIR.backup-$(date +%Y%m%d%H%M%S)"
    info "previous ~/ollama moved aside as a backup"
  fi
  mv "$STAGE" "$OLLAMA_DIR"
  info "installed to $OLLAMA_DIR"
fi
ln -sf "$OLLAMA_BIN" "$BIN_DIR/ollama"

# ---------------------------------------------------------------- Ollama service
log "Ollama service"
if [ -f "$SCRIPT_DIR/setup-ollama-service.sh" ] && bash "$SCRIPT_DIR/setup-ollama-service.sh"; then
  info "systemd service up"
else
  warn "systemd path unavailable — starting ollama serve via nohup fallback"
  if ! curl -fsS --max-time 2 "$OLLAMA_HOST_URL/api/version" >/dev/null 2>&1; then
    OLLAMA_HOST=127.0.0.1:11434 OLLAMA_MODELS="$HOME/.ollama/models" \
      nohup "$OLLAMA_BIN" serve > "$STATE_DIR/ollama.log" 2>&1 &
    echo $! > "$STATE_DIR/ollama.pid"
  fi
fi

info "waiting for the API on $OLLAMA_HOST_URL ..."
for i in $(seq 1 60); do
  if curl -fsS --max-time 2 "$OLLAMA_HOST_URL/api/version" >/dev/null 2>&1; then break; fi
  [ "$i" -eq 60 ] && die "Ollama API did not come up within 60s (see: systemctl status ollama / $STATE_DIR/ollama.log)"
  sleep 1
done
info "API is up: $(curl -fsS "$OLLAMA_HOST_URL/api/version")"

# ---------------------------------------------------------------- Model
if [ "$SKIP_MODEL" -eq 0 ]; then
  log "Model $OLLAMA_MODEL"
  if OLLAMA_HOST=127.0.0.1:11434 "$OLLAMA_BIN" list 2>/dev/null | awk '{print $1}' | grep -qx "$OLLAMA_MODEL" && [ "$FORCE" -eq 0 ]; then
    info "already pulled (skip)"
  else
    OLLAMA_HOST=127.0.0.1:11434 "$OLLAMA_BIN" pull "$OLLAMA_MODEL"
  fi
else
  info "skipping model pull (--skip-model)"
fi

# ---------------------------------------------------------------- Manifest + verify
cat > "$STATE_DIR/install-manifest.json" <<EOF
{
  "installed_at": "$(date -Iseconds)",
  "hypit_version": "$HYPIT_VERSION",
  "hypit_skill": "$SKILL_DIR",
  "hypit_cli": "$HYPIT_BIN",
  "ollama_version": "$OLLAMA_VERSION",
  "ollama_binary": "$OLLAMA_BIN",
  "ollama_api": "$OLLAMA_HOST_URL",
  "model": "$OLLAMA_MODEL",
  "sources": {
    "hypit_repo": "https://github.com/hypit-ai/hypit",
    "hypit_npm": "https://registry.npmjs.org/@hypit/hypit/-/@hypit/hypit-${HYPIT_VERSION}.tgz",
    "ollama_release": "$OLLAMA_BASE_URL/$OLLAMA_ARCHIVE"
  }
}
EOF
info "manifest written to $STATE_DIR/install-manifest.json"

log "Verification"
if [ "$SKIP_SMOKE" -eq 1 ]; then
  bash "$SCRIPT_DIR/verify.sh" --no-smoke
else
  bash "$SCRIPT_DIR/verify.sh"
fi

log "Done"
info "Use it:  export PATH=\"$BIN_DIR:\$PATH\""
info "Hypit:   hypit --version   |   Ollama API: $OLLAMA_HOST_URL"
info "If the VM is replaced and ollama.service vanishes, re-run: bash setup-ollama-service.sh"

#!/usr/bin/env bash
# setup-ollama-service.sh — (re)create the Ollama systemd unit from the CURRENT
# environment (proxy variables included) and start the service.
#
# Why this exists: on Muse VMs the root filesystem (/etc) does not survive a
# VM replacement, while $HOME does. After a restart the unit file is gone even
# though ~/ollama and ~/.ollama/models are intact — just re-run this script.
#
# Env overrides: TARGET_HOME (default $HOME), TARGET_USER (default current user),
# OLLAMA_BIN (default $TARGET_HOME/ollama/bin/ollama).
# Exit codes: 0 ok, 1 error, 2 systemd not available (caller may fall back to nohup).
set -Eeuo pipefail

TARGET_HOME="${TARGET_HOME:-$HOME}"
TARGET_USER="${TARGET_USER:-$(id -un)}"
OLLAMA_BIN="${OLLAMA_BIN:-$TARGET_HOME/ollama/bin/ollama}"
MODELS_DIR="$TARGET_HOME/.ollama/models"
UNIT_PATH="/etc/systemd/system/ollama.service"

[ -x "$OLLAMA_BIN" ] || { echo "ERROR: ollama binary not found at $OLLAMA_BIN" >&2; exit 1; }

if ! command -v systemctl >/dev/null 2>&1 || [ ! -d /run/systemd/system ]; then
  echo "systemd is not available on this machine." >&2
  exit 2
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else
    echo "ERROR: need root or sudo to write $UNIT_PATH" >&2; exit 1
  fi
fi

TMP_UNIT="$(mktemp)"
trap 'rm -f "$TMP_UNIT"' EXIT
{
  printf '[Unit]\nDescription=Ollama Service\nAfter=network-online.target\n\n[Service]\n'
  printf 'ExecStart=%s serve\n' "$OLLAMA_BIN"
  printf 'User=%s\n' "$TARGET_USER"
  printf 'Restart=always\nRestartSec=3\n'
  printf 'Environment="HOME=%s"\n' "$TARGET_HOME"
  printf 'Environment="OLLAMA_HOST=127.0.0.1:11434"\n'
  printf 'Environment="OLLAMA_MODELS=%s"\n' "$MODELS_DIR"
  # Bake the caller's proxy settings into the unit: the service process itself
  # needs them to pull models; a shell-only proxy is not enough.
  for v in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY; do
    if [ -n "${!v:-}" ]; then
      printf 'Environment="%s=%s"\n' "$v" "${!v}"
    fi
  done
  printf '\n[Install]\nWantedBy=default.target\n'
} > "$TMP_UNIT"

$SUDO install -m 0644 "$TMP_UNIT" "$UNIT_PATH"
$SUDO systemctl daemon-reload
$SUDO systemctl enable --now ollama
echo "ollama.service installed and started (HOME=$TARGET_HOME, user=$TARGET_USER)."

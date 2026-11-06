#!/usr/bin/env bash
# uninstall.sh — remove what install.sh added. Destructive steps need --yes.
# By default the Ollama model store (~/.ollama) is KEPT; add --purge to drop it too.
set -Eeuo pipefail

YES=0; PURGE=0
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    --purge) PURGE=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
[ "$YES" -eq 1 ] || { echo "Refusing to run without --yes. Usage: ./uninstall.sh --yes [--purge]"; exit 2; }

SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

if command -v systemctl >/dev/null 2>&1 && [ -f /etc/systemd/system/ollama.service ]; then
  $SUDO systemctl disable --now ollama 2>/dev/null || true
  $SUDO rm -f /etc/systemd/system/ollama.service
  $SUDO systemctl daemon-reload || true
  echo "removed ollama.service"
fi

rm -f "$HOME/.local/bin/hypit" "$HOME/.local/bin/ollama"
rm -rf "$HOME/.local/share/hypit-cli"
rm -rf "$HOME/.agents/skills/hypit"
rm -rf "$HOME/ollama"
rm -rf "$HOME/.cache/puppeteer" "$HOME/.cache/hypit"
rm -rf "$HOME/.local/state/muse-hypit-ollama-kit"
rm -rf "$HOME/workspace/tools/omniget" "$HOME/.local/share/com.openselena.omniget"
echo "removed hypit skill/CLI/browsers, ~/ollama binaries and the omniget capture tool (downloads under ~/workspace/downloads were kept)"

if [ "$PURGE" -eq 1 ]; then
  rm -rf "$HOME/.ollama"
  echo "purged ~/.ollama (models deleted)"
else
  echo "kept ~/.ollama (models). Re-run with --purge to delete them."
fi
echo "Note: ~/ollama-dist (downloaded archives) was left in place; delete it by hand if unwanted."

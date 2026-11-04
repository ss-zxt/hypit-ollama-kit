#!/usr/bin/env bash
# bootstrap.sh — fetch this kit from GitHub and run install.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/<you>/hypit-ollama-kit/main/bootstrap.sh | bash
#
# Or set the repo explicitly:
#   KIT_REPO=<you>/hypit-ollama-kit KIT_REF=main bash bootstrap.sh [--skip-smoke ...]
#
# Any extra arguments are passed through to install.sh. The kit sources are
# unpacked into a temp dir; for upgrades later, prefer `git clone` so
# upgrade.sh can edit versions.env in a persistent checkout.
set -Eeuo pipefail

KIT_REPO="${KIT_REPO:-your-github-name/hypit-ollama-kit}"
KIT_REF="${KIT_REF:-main}"

if [ "$KIT_REPO" = "your-github-name/hypit-ollama-kit" ]; then
  echo "ERROR: set KIT_REPO to the real GitHub repo (e.g. KIT_REPO=me/hypit-ollama-kit)." >&2
  exit 2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading $KIT_REPO@$KIT_REF ..."
curl -fsSL "https://codeload.github.com/${KIT_REPO}/tar.gz/refs/heads/${KIT_REF}" -o "$TMP/kit.tar.gz"
mkdir -p "$TMP/kit"
tar -xzf "$TMP/kit.tar.gz" -C "$TMP/kit" --strip-components=1
bash "$TMP/kit/install.sh" "$@"

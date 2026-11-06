# Hypit + Ollama + qwen3:1.7b — One-Click Replication Kit

> 中文版：[README.md](README.md)
>
> ⭐ **Found it useful?** Please star the repo on GitHub — it is the best
> way to support this kit:
> [github.com/ss-zxt/hypit-ollama-kit](https://github.com/ss-zxt/hypit-ollama-kit)

Take the environment verified on one Muse account and reproduce it, as-is,
on another: **Hypit (skill + CLI + two headless browsers) + open-source
Ollama + the Qwen qwen3:1.7b local model** — everything downloaded from
official sources, versions pinned, and the Ollama package SHA-256-verified.

> **Full documentation: [MANUAL_EN.md](MANUAL_EN.md)** — features, every
> script's options, end-to-end workflows and troubleshooting all live in
> that one file. This README is only the quick start.
> (Chinese manual: [使用手册.md](使用手册.md))

## Requirements (summary; full version in Manual §3.1)

- **OS**: Linux x86_64 (glibc). Tested baseline: Ubuntu 24.04.5 LTS (Muse
  VM, 4 vCPU / 7.7 GB RAM). Ubuntu 22.04 and Debian 12 are expected to work.
  Native macOS / Windows and ARM64 are not supported; WSL2 can install in
  fallback mode.
- **Hard floors**: Node.js ≥ 22.15.0 (Hypit's own requirement; the
  preflight stops without it), Python 3 ≥ 3.10, ≥ 8 GB free under $HOME,
  RAM ≥ 4 GB (8 GB+ recommended).
- With systemd, Ollama is registered as a service; without it, the script
  falls back to a plain background launch. GPU optional (NVIDIA VRAM is used
  automatically when present).
- Not sure a machine qualifies? Run `./install.sh --check-only` for an
  environment report first.
- The model is pinned to qwen3:1.7b by default; on a stronger machine,
  `./install.sh --auto-model` picks 4b/8b/14b by RAM/VRAM (see Manual §4.1).

## One-click install

```bash
tar -xzf hypit-ollama-replication-kit.tar.gz
cd hypit-ollama-replication-kit
./install.sh
```

## Using it as a GitHub project (after publishing)

This folder is itself a complete git repository. Once published to GitHub,
others can install it two ways:

```bash
# Option 1: clone and install (recommended — upgrade.sh then upgrades in place)
git clone https://github.com/ss-zxt/hypit-ollama-kit.git
cd hypit-ollama-kit && ./install.sh

# Option 2: one-liner
curl -fsSL https://raw.githubusercontent.com/ss-zxt/hypit-ollama-kit/main/bootstrap.sh | KIT_REPO=ss-zxt/hypit-ollama-kit bash
```

To publish: create an empty GitHub repository (e.g. `hypit-ollama-kit`,
without initializing a README), then in this directory run
`git remote add origin <repo-url>` and `git push -u origin main`. The kit
contains no account, token or proxy address (proxies are read from the
target machine's environment at install time), so it is safe to publish
publicly. The scripts and docs are MIT-licensed (see LICENSE); Hypit /
Ollama / the models are downloaded from their official sources at install
time, are not redistributed with the repo, and follow their own upstream
licenses.

After installing, the script automatically runs `verify.sh` (including one
real inference smoke test). Budget **~3.5 GB of downloads** in total (Ollama
1.5G + model 1.4G + browsers ~0.6G) and at least 6.5 GB of disk.

The scripts are **idempotent**: re-running skips what is already installed
and fills in only what is missing — e.g. after a Muse VM replacement, the
systemd unit in /etc is gone but the binaries and models under home survive;
one more `./install.sh` (or `bash setup-ollama-service.sh` on its own)
restores the service.

## Copying it to another Muse account

1. Send `hypit-ollama-replication-kit.tar.gz` (or the whole folder) to the
   target account;
2. Paste the text from `AGENT_PROMPT.md` to that account's Muse — it will
   unpack, install, verify and report back by itself;
3. …or just run the three commands above in a terminal yourself.

## The TikTok capture method is in the kit too (tiktok/ directory)

- `tiktok/TIKTOK_METHOD.md` — the fixed capture method in full (Chinese):
  download TikTok reference clips with **omniget-cli** (the command-line
  build of the open-source OpenSelena/omniget project) — short links
  (vt.tiktok.com) resolve directly, the proxy rule that is mandatory on
  Muse VMs, retry/fallback rules, and the post-download decomposition
  flow. Two companion scripts: `tiktok/install-omniget.sh` (one-time tool
  install, version-pinned and SHA-256 verified) and
  `tiktok/download-tiktok.sh "<url>"` (one command to download + verify).
- `tiktok/prepare-reference.sh` — the automation after downloading: archives
  the file into a standard decomposition project
  (`~/workspace/hypit-projects/<project-name>/`) and automatically produces
  the specs / candidate cut points / volume report plus a frame grid at
  0.5-second intervals, ready for frame-by-frame decomposition.

## What you get after installing

| Component | Location | Notes |
|---|---|---|
| Hypit skill | `~/.agents/skills/hypit` | Muse's skill directory; survives restarts |
| Hypit CLI 0.3.1 | `~/.local/share/hypit-cli`, symlink `~/.local/bin/hypit` | Pinned version, home install |
| Capture browser | `~/.cache/puppeteer` (Chrome for Testing 153) | Used by `hypit capture` |
| Renderer browser | `~/.cache/hypit` (Chrome Headless Shell 152) | Used by Hypit's production render pipeline |
| Ollama 0.40.14 | `~/ollama`, symlink `~/.local/bin/ollama` | Official release package, SHA-256 verified |
| Ollama service | systemd `ollama.service`, API `http://127.0.0.1:11434` | The current environment's proxy variables are baked into the unit (the service process needs them to pull models) |
| qwen3:1.7b | `~/.ollama/models` | Pulled from the official model library, ~1.4 GB |

Put the symlink directory on your PATH first (Muse terminals usually
include it already):

```bash
export PATH="$HOME/.local/bin:$PATH"
hypit --version          # 0.3.1
curl http://127.0.0.1:11434/api/version
ollama list              # should show qwen3:1.7b
```

## Optional flags

```bash
./install.sh --check-only     # environment preflight only, installs nothing
./install.sh --skip-browsers  # skip both browser downloads
./install.sh --skip-model     # skip pulling the model
./install.sh --skip-smoke     # skip the final inference smoke test
./install.sh --force          # force-reinstall existing components
bash verify.sh                # re-verify any time (--no-smoke skips inference)
bash setup-ollama-service.sh  # restore the Ollama service alone after a VM restart
./uninstall.sh --yes          # uninstall (keeps ~/.ollama models; add --purge to delete them too)
```

All versions are pinned in `versions.env` — upgrading means editing that
one file; sources and checksums are in `SOURCES.md`.

## What if the official versions move on?

**No automatic upgrades by default** — pins exist so every account installs
the identical, verified environment; a major upstream release can change
command or config formats, and blindly auto-upgrading can break a working
setup. When you do want to upgrade, the bundled script does it in one
command:

```bash
./upgrade.sh --check   # check only: current pins vs official latest (changes nothing)
./upgrade.sh           # upgrade: refresh versions & checksums in versions.env → reinstall → auto-verify (incl. inference test)
```

Safety measures: `versions.env` is backed up (timestamped) before
upgrading, and install.sh keeps the old `~/ollama` under a renamed
directory; if post-upgrade verification fails, the one-liner printed at the
end of the script rolls you back to the old version. Three details: the
Hypit skill itself is not separately pinned (upgrading reinstalls it at the
repo's latest); qwen3:1.7b is a floating tag, so "upgrading the model"
means re-pulling to refresh the digest, which `./upgrade.sh` also does when
nothing else changed; changing the model *size* (e.g. to 4b) is an
`OLLAMA_MODEL` edit in `versions.env` and never happens automatically.

## Known notes (all field-tested)

- **Installing everything under home is deliberate**: a Muse VM's root
  filesystem (/usr, /etc, apt state) does not survive a VM replacement —
  global npm installs and an apt-installed zstd have both been wiped before;
  home is what survives.
- **The Ollama service must carry the proxy**: Muse's egress proxy
  existing in your shell is not enough — the service process itself needs
  network access to pull models, so `setup-ollama-service.sh` writes the
  current environment's `http_proxy/https_proxy` variables into the systemd
  unit. Re-run the script after an environment change to refresh them; the
  script never prints proxy addresses.
- **qwen3 needs thinking mode off**: by default, thinking burns the whole
  token budget before answering; pass `"think": false` in API calls
  (verify.sh's smoke test does exactly this).
- **`hypit capture screenshot` fails as root** (that command launches Chrome
  without `--no-sandbox`), but the production render pipeline passes the
  flag itself and is unaffected — it does not block production.
- **`hypit programs prepare` must run inside a project**: it requires the
  current directory to be a Hypit project with a selected Runtime and
  errors out in an empty directory. install.sh runs this step through the
  bundled minimal sample project (`smoke-project/`, with the verified
  two-endpoint runtime config); when adding the renderer browser manually,
  do the same instead of running it from your home directory. Note also
  that a fresh `runtime init` config includes an opencv endpoint that needs
  `uv`; this kit's config keeps only the two verified endpoints (media +
  html) and is unaffected.
- The kit supports **Linux x86_64 only** (verified on a Ubuntu 24.04 Muse
  VM); the pinned Ollama asset is the linux-amd64 build.

## Support

If this kit saved you time, please give it a ⭐ star on GitHub:
https://github.com/ss-zxt/hypit-ollama-kit — it is the most direct way to
encourage the maintainer, and it helps others find the kit.

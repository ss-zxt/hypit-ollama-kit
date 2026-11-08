# User Manual — Hypit + Ollama + qwen3:1.7b Replication Kit (Full Features & Usage)

> 中文版：[使用手册.md](使用手册.md)

This manual is the kit's **master document**: feature overview, every script's
usage and options, end-to-end workflows, and troubleshooting all live here.
The other documents are its companions: `SOURCES.md` (sources & checksums),
`AGENT_PROMPT.md` (paste-in instructions for Muse), and
`tiktok/TIKTOK_METHOD.md` (the full TikTok capture method).

---

## 1. What this kit does

It turns a short-video production environment, verified on one Muse machine,
into a **one-click installable kit for any Muse account / Linux x86_64
machine**:

| Capability | Components | Purpose |
|---|---|---|
| Template decomposition & prompt drafting | Hypit skill + CLI 0.3.1 | Break a reference video down into structure (shots / actions / cut points), batch-swap words and images, produce generation prompts |
| Local small model | Ollama 0.40.14 + Qwen qwen3:1.7b | Run a local model offline to assist decomposition, rewriting and classification — no cloud tokens spent |
| Headless browsers ×2 | Chrome for Testing 153 + Headless Shell 152 | Hypit's web capture and its production rendering pipeline |
| TikTok capture method | tiktok/ directory | A fixed omniget-cli (command-line) way to fetch reference clips, plus automatic post-download archiving and frame evidence |

Design principles (all learned the hard way):

- **Official sources only**: GitHub (hypit-ai/hypit, ollama/ollama), the npm
  registry, and the official Ollama model library. Every version is pinned in
  `versions.env`, and the Ollama package is SHA-256-verified on every install.
- **Everything installs under $HOME**: on Muse VMs the root filesystem (/usr,
  /etc) does not survive a VM replacement, so global installs get wiped — the
  CLI, browser caches, binaries and models all live under `$HOME`. Only the
  systemd unit lives in /etc, and a dedicated script rebuilds it in one step.
- **Idempotent**: every script can be re-run safely; what is already installed
  is skipped, only the missing parts are filled in.

## 2. What's in the kit (file map)

```
install.sh                  One-click installer (idempotent)
verify.sh                   Full verification (incl. a real inference test)
upgrade.sh                  Check/apply official upgrades (with backup & rollback notes)
setup-ollama-service.sh     (Re)create Ollama's systemd service on its own
uninstall.sh                Uninstall (requires --yes)
bootstrap.sh                One-line install from GitHub (after publishing)
extract_zst.py              Python fallback unpacker when zstd is absent (called internally)
select-model.sh             Pick a qwen3 size by RAM/VRAM (used by --auto-model)
versions.env                The single version-pin file (upgrades touch only this)
smoke-project/              Minimal Hypit project (drives the renderer prepare step, see §7 #1)
tiktok/TIKTOK_METHOD.md     The full TikTok capture method (omniget-cli command-line steps, Chinese)
tiktok/install-omniget.sh   One-time installer for the capture tool (omniget-cli + yt-dlp, SHA-256 verified)
tiktok/download-tiktok.sh   Download one TikTok link with a single command (proxy rule built in)
tiktok/prepare-reference.sh Post-download archiving + frame-evidence script
README.md                   Quick start (Chinese)
README_EN.md                Quick start (English)
使用手册.md                  This manual in Chinese
MANUAL_EN.md                This manual (English)
SOURCES.md                  Official links, versions and checksums for every component
AGENT_PROMPT.md             Paste-in instructions for the receiving Muse
LICENSE                     MIT (covers this kit's scripts and docs only)
```

Machine layout after installation:

```
~/.agents/skills/hypit            Hypit skill
~/.local/share/hypit-cli          Hypit CLI itself (~/.local/bin/hypit is a symlink)
~/.cache/puppeteer                Capture Chrome
~/.cache/hypit                    Renderer Headless Shell
~/ollama                          Ollama itself (~/.local/bin/ollama is a symlink)
~/.ollama/models                  Models (incl. qwen3:1.7b, ~1.4 GB)
~/ollama-dist                     Ollama package cache (verified; keep for offline reinstall)
/etc/systemd/system/ollama.service  Service (proxy vars baked in, API 127.0.0.1:11434)
~/.local/state/muse-hypit-ollama-kit/  State, incl. install-manifest.json
~/workspace/tools/omniget/omniget-cli   TikTok capture tool (installed by tiktok/install-omniget.sh)
~/.local/share/com.openselena.omniget/bin/yt-dlp  Capture engine (hand-placed copy, do not delete)
```

## 3. Installation

### 3.1 Supported environments (OS / VM / hardware)

**Field-tested environment** (this kit was developed and fully verified on
this exact machine):

| Item | Tested value |
|---|---|
| Environment | Muse VM (cloud Linux VM) |
| OS | Ubuntu 24.04.5 LTS, kernel 7.0.0-39, glibc 2.39 |
| CPU / RAM | 4 vCPU (x86_64, AVX2), 7.7 GB RAM |
| Runtime | systemd as PID 1; Node v24.22.1 / npm 10.9.4; Python 3.12.3; ffmpeg 8.1.2 |
| Disk layout | Root overlay only 7.5 GB, home ~139 GB — the kit installs entirely under home for exactly this reason |

**OS requirements**:

- Must be a **Linux x86_64 + glibc** distribution. Ubuntu 24.04 LTS is the
  tested baseline; Ubuntu 22.04 LTS and Debian 12 are expected to work (same
  glibc + systemd + apt stack) but were not individually tested.
- **Node.js ≥ 22.15.0 is a hard floor** (declared in Hypit 0.3.1's own
  `engines` field). install.sh's preflight stops with an explanation if it is
  not met; npm/npx ship with Node. Node is checked, never installed for you.
- Python 3 ≥ 3.10 (used only by the unpack fallback and verification scripts;
  tested 3.12.3).
- With systemd present, Ollama is registered as a system service; **without
  systemd the install still works** (the script falls back to a nohup launch),
  you just lose boot persistence and service management.
- musl-based distributions such as Alpine are not supported (the official
  Ollama package targets glibc).

**VM / runtime environment matrix**:

| Environment | Support | Notes |
|---|---|---|
| Muse VM / account | ✅ Tested | Primary scenario; after a VM replacement, re-run install.sh or the setup script to restore the service |
| Cloud server / physical machine (Ubuntu/Debian x86_64) | ✅ | Normal user + sudo is enough; an NVIDIA GPU is used automatically when present |
| WSL2 (Ubuntu on Windows) | ⚠️ Installable | No systemd by default → fallback mode (or enable systemd in wsl.conf); not specifically tested |
| Docker container | ⚠️ Installable | No systemd → fallback mode; Hypit's render pipeline passes --no-sandbox itself; not specifically tested |
| macOS / native Windows | ❌ | The kit pins the Linux Ollama package and the systemd route; would need separate branches |
| ARM64 (Raspberry Pi, ARM cloud hosts, etc.) | ❌ | Pinned assets are amd64; official arm64 packages exist but are not adapted here |

**Hardware requirements**:

- CPU: any x86_64 (Ollama ships multiple CPU builds from SSE4.2 up to
  AVX512/zen4 and picks automatically; AVX2 is noticeably faster).
- RAM: 4 GB minimum (running only the 1.7b), 8 GB+ recommended; the more
  RAM/VRAM you have, the larger the model you can run — see the automatic
  model selection in §4.1.
- Disk: reserve at least 8 GB under home (the script warns below 6.5 GB
  free): Ollama itself 2.4 GB + package cache 1.5 GB + models from 1.4 GB
  (more with a larger auto-selected model) + browsers ~0.7 GB.
- GPU: optional. With a working NVIDIA driver, Ollama uses VRAM for
  inference automatically; without one it is pure CPU, which is acceptable
  for small models like 1.7b/4b.
- Network: install and upgrade need egress to github.com,
  registry.npmjs.org and registry.ollama.ai; behind a proxy, the scripts
  inherit `http_proxy/https_proxy` and friends from the environment. After
  installation, inference and decomposition run fully offline.

Not sure a target machine qualifies? Run `./install.sh --check-only` first:
it prints the detected OS, kernel, RAM, systemd and Node versions with a
verdict, and installs nothing.

### 3.2 Three ways to install

```bash
# A. From the archive (the current primary route)
tar -xzf hypit-ollama-replication-kit.tar.gz
cd hypit-ollama-replication-kit && ./install.sh

# B. Git clone (after publishing to GitHub)
git clone https://github.com/ss-zxt/hypit-ollama-kit.git
cd hypit-ollama-kit && ./install.sh

# C. Hand it to the target account's Muse: paste AGENT_PROMPT.md to it
```

### 3.3 install.sh options

| Option | Effect |
|---|---|
| (none) | Full install: skill → CLI → browsers → Ollama → service → model → auto-verify |
| `--check-only` | Environment preflight only (OS/arch/commands/disk); installs nothing |
| `--skip-browsers` | Skip both browser downloads (saves ~0.6 GB; can be added later) |
| `--skip-model` | Skip pulling qwen3:1.7b (saves ~1.4 GB) |
| `--skip-smoke` | Skip the final inference smoke test (other checks still run) |
| `--skip-omniget` | Skip the TikTok capture tool (omniget-cli + yt-dlp, ~9 MB; add later with `bash tiktok/install-omniget.sh`). A failed capture-tool install only warns and never aborts the main install |
| `--auto-model` | Instead of the pinned 1.7b, pick a qwen3 size by this machine's RAM/VRAM (see §4.1) |
| `--force` | Force-reinstall components that are already present (upgrades, repairs) |

Interrupted mid-install? Just re-run `./install.sh` — it resumes from
whatever is missing.

## 4. Using it after installation

```bash
export PATH="$HOME/.local/bin:$PATH"   # Muse terminals usually include it already
hypit --version                        # 0.3.1
ollama list                            # should show qwen3:1.7b
curl http://127.0.0.1:11434/api/version
```

- **Hypit**: in Muse, just ask normally (the skill is picked up
  automatically); the CLI entry point is `hypit` — commonly used:
  `hypit media probe/boundaries/tiles <video>` for decomposition evidence.
- **Ollama/Qwen**: when calling the API, **always pass `"think": false`**,
  otherwise qwen3's thinking mode burns the whole output budget before
  answering. Example:

  ```bash
  curl http://127.0.0.1:11434/api/generate -d '{
    "model": "qwen3:1.7b",
    "prompt": "Rewrite this video caption into three titles",
    "stream": false, "think": false }'
  ```

- **Changing the model size**: edit `OLLAMA_MODEL` in `versions.env` (e.g.
  `qwen3:4b`) and re-run `./install.sh`. The old model is not deleted;
  clean up manually with `ollama rm <name>`.

### 4.1 Automatic model selection by machine spec (optional)

The default is the pinned `qwen3:1.7b` — the point is that every account
installs the identical environment, and it runs even on the weakest machine.
On a stronger machine you can let the installer **pick a larger Qwen by
RAM/VRAM**:

```bash
./install.sh --auto-model
# or set OLLAMA_MODEL to auto in versions.env — same effect
```

Selection rules (`select-model.sh`; run it alone to see the verdict without
installing). **RAM is rounded to the nearest GiB**: a nominal 8 GB machine
reports only ~7.9 GiB of MemTotal, and it is tiered as 8 GB — it does not
drop a tier:

| Machine spec | Model selected | Download approx. |
|---|---|---|
| VRAM ≥ 16 GB or RAM ≥ 32 GB | qwen3:14b | 9.3 GB |
| VRAM ≥ 8 GB or RAM ≥ 16 GB | qwen3:8b | 5.2 GB |
| RAM ≥ 8 GB | qwen3:4b | 2.5 GB |
| Anything else (floor) | qwen3:1.7b | 1.4 GB |

The chosen tag is recorded in
`~/.local/state/muse-hypit-ollama-kit/resolved-model.txt`, and `verify.sh`
and `upgrade.sh` follow it (checks and refreshes target the model actually
installed). Note: with auto-selection, machines no longer end up with the
same model — for a perfectly reproducible environment, leave it off; to go
back, restore the fixed tag and re-run `./install.sh`.

## 5. The TikTok reference workflow, end to end

1. Fetch the clip from the command line, following
   `tiktok/TIKTOK_METHOD.md` — run `bash tiktok/install-omniget.sh` once
   to install omniget-cli (the CLI of OpenSelena/omniget), then
   `bash tiktok/download-tiktok.sh "<TikTok URL>"` downloads in one
   command (info first for title/author/duration, then the download and
   an ffprobe check). On Muse VMs the environment proxy is mandatory
   (the script applies `$HTTPS_PROXY` for you; without it every fetch
   fails with a misleading "extractor broken" error). Short links
   (vt.tiktok.com) resolve directly. Only if omniget fails twice, fall
   back to the SaveFrom browser method kept at the end of that document.
2. Archive and extract evidence:
   `bash tiktok/prepare-reference.sh <downloaded file> <english-project-name>`
   → creates, under `~/workspace/hypit-projects/<project-name>/`:
   `references/source.mp4`, `references/PROBE.txt` (specs + candidate change
   points + volume) and `evidence/tiles/` (a 0.5-second frame grid).
3. Write the decomposition (TIMELINE/ANALYSIS) and the prompt package only
   after studying the frame grid; `boundaries` only offers *candidate*
   change points — whether a point is a real cut must be confirmed by eye.

## 6. Day-to-day maintenance

### 6.1 Verify

```bash
bash verify.sh              # all 11 checks + one Chinese inference test
bash verify.sh --no-smoke   # quick version without the inference test
```

Every [FAIL] line ends with its fix command (e.g. service down → run the
setup script).

### 6.2 Update the kit itself (when the repo publishes a new version)

Keep this separate from §6.3: this updates **a new version of this kit**
(its scripts, docs and components — e.g. the 2026-11-06 switch of the
TikTok capture method to omniget-cli), not the official Hypit/Ollama
version numbers. Pick by how the machine was installed:

```bash
# Route 1: installed via git clone (recommended)
cd hypit-ollama-kit
git pull --ff-only
./install.sh        # idempotent: skips what is in place, adds only what is new
bash verify.sh      # ALL CHECKS PASSED means the update is complete

# Route 2: installed from an archive
# Download the new tar.gz/zip, unpack it over the old kit directory
# (or into a fresh one), then inside the kit directory:
./install.sh
bash verify.sh
```

Notes:

- install.sh is idempotent — an update never reinstalls components that
  are already in place and never touches pulled models, so re-run it
  without worry.
- Machines installed via the one-line bootstrap have no persistent kit
  checkout; switch to a `git clone` install if you want updates this way.
- If a new version changes the pins in versions.env (new components /
  new versions), re-running install.sh fills in everything to the new
  pins, and verify.sh's checks line up with them.

### 6.3 Upgrade (when official releases move)

```bash
./upgrade.sh --check   # compare only: current pins vs official latest (live from npm + GitHub)
./upgrade.sh           # upgrade: back up versions.env → refresh versions & checksums → reinstall → full verify
```

- **No automatic upgrades by default**: pinned versions keep every account's
  environment identical and verified; a major release can change command or
  config formats, so upgrading is a deliberate one-click action.
- Rollback: on failure the script prints a ready-made one-liner (restore the
  backed-up versions.env, then `./install.sh --force`); the old `~/ollama`
  is also kept under a renamed directory.
- The Qwen tag floats: even with no new version, `./upgrade.sh` re-pulls to
  refresh the model digest.

### 6.4 VM replaced / rebooted and the Ollama service is gone

Everything under home is still there; only the unit in /etc is missing:

```bash
bash setup-ollama-service.sh   # rebuild the service from the current environment (proxy included) and start it
# or simply re-run ./install.sh (idempotent; it fills in whatever is missing)
```

### 6.5 Uninstall

```bash
./uninstall.sh --yes            # removes service/skill/CLI/browsers/Ollama, keeps models
./uninstall.sh --yes --purge    # also deletes the models in ~/.ollama
```

`~/ollama-dist` (the package cache) is not removed automatically; delete it
manually if you want it gone.

## 7. Troubleshooting (field-tested pitfalls)

| Symptom | Cause & fix |
|---|---|
| `hypit programs prepare` says "No Hypit project was found" | The command only runs inside a project with a selected Runtime. install.sh runs it for you through the bundled `smoke-project/`; to do it manually, cd into any Hypit project, or copy smoke-project into the state dir the way install.sh does, then `hypit runtime use ./hypit.runtime.json && hypit programs prepare` |
| The opencv endpoint in a fresh `runtime init` config fails (uv missing) | The default new config includes an image.opencv endpoint that needs `uv`. The kit's smoke-project uses the verified media+html two-endpoint config and is unaffected; opencv is only an image-processing endpoint and is not needed for decomposition/rendering |
| `hypit capture screenshot` fails as root | That command launches Chrome without `--no-sandbox`; the production render pipeline passes it itself, so only the standalone screenshot command is limited |
| Ollama API unreachable, model pulls fail | Start with `systemctl status ollama`; usually the service vanished in a VM replacement → §6.4. Another common cause: the service process has no proxy (having one in your shell is not enough) → the setup script writes the current environment's proxy variables into the unit; re-run it after an environment change. **One more, field-tested 2026-11-05: `ollama pull` hangs ~60 s at "pulling manifest" and fails with `context deadline exceeded`, while curl to the model registry from your shell is instant** — the proxy address baked into the service unit has gone stale (the machine's egress proxy rotated). Re-running `setup-ollama-service.sh` to rebuild the service from the current environment fixes it; no reinstall needed |
| qwen3 answers empty / takes forever | Thinking mode is on: add `"think": false` to the request (see §4) |
| Unpacking the Ollama package fails | The fallback chain is tar --zstd → the zstd binary → the Python zstandard module (extract_zst.py); if all three are missing the script tries to pip-install zstandard. On a checksum failure, delete the package in `~/ollama-dist` and re-download |
| `hypit media tiles` says "no video frame exists at or after Ns" | The sampling end hit the exact total duration; set --end to the duration −0.1s (prepare-reference.sh has this built in) |
| Not enough disk | The full set needs ~6.5 GB; install the core first with `--skip-browsers --skip-model`, then add the rest later |

## 8. Version quick reference (full provenance in SOURCES.md)

| Component | Pinned version | Official source |
|---|---|---|
| Hypit skill | Tracks the repo's latest | github.com/hypit-ai/hypit |
| Hypit CLI | 0.3.1 | npm @hypit/hypit |
| Capture browser | Chrome for Testing 153.0.8010.12 | Fetched by Hypit's commands |
| Renderer browser | Chrome Headless Shell 152.0.7928.2 | Fetched by Hypit's commands |
| Ollama | 0.40.14 (SHA-256 verified) | github.com/ollama/ollama releases |
| Model | qwen3:1.7b | Official Ollama model library |

## 9. License & boundaries

- This kit's scripts and docs: MIT (see LICENSE).
- Hypit, Ollama and the qwen3 models are downloaded from their official
  sources at install time and are not redistributed with the kit; each
  follows its own upstream license (see SOURCES.md).
- The kit contains no account, token or proxy address; proxies are read from
  the target machine's current environment at install time and are never
  written into any file in the kit (except the service unit — which is the
  target machine's own system configuration).

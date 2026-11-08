# SOURCES — 安装来源与校验（2026-11-04 实测核对）

所有组件都从官方来源获取，不含任何第三方镜像或改包。

## Hypit（开源，hypit-ai）

- 仓库：https://github.com/hypit-ai/hypit
- Skill 安装命令：`npx -y skills add hypit-ai/hypit -g -y`
  （`-y` 必带，否则安装器会卡在交互确认上）
- CLI：npm 包 `@hypit/hypit@0.3.1`
  - tarball：https://registry.npmjs.org/@hypit/hypit/-/hypit-0.3.1.tgz
  - integrity：`sha512-FI54GPQRB9uXSTRmCt8fngzWH/YEEasOIuYhwsEh9G2v92L50N/TdcMiLgDT1KfRjt+C1/HXcG28Bai6HMEDQQ==`
- 浏览器由 Hypit 自己的命令拉取（Chrome 官方分发）：
  - `hypit capture install-browser` → Chrome for Testing 153.0.8010.12（`~/.cache/puppeteer`）
  - `hypit programs prepare` → Chrome Headless Shell 152.0.7928.2（`~/.cache/hypit`）

## Ollama（开源，ollama/ollama）

- 仓库：https://github.com/ollama/ollama
- 锁定版本：v0.40.14，资产 `ollama-linux-amd64.tar.zst`（1,525,335,029 字节）
  - 下载：https://github.com/ollama/ollama/releases/download/v0.40.14/ollama-linux-amd64.tar.zst
    （与官网 https://ollama.com/download/ollama-linux-amd64.tar.zst 为同一资产）
  - 官方校验文件：同 release 的 `sha256sum.txt`
  - SHA-256：`993e83d08c3d13d17c55009a3e2664c8a25445e644aec3a68bef5abb6abce67d`
    （本地已下载文件与官方校验值比对一致；install.sh 每次安装都会重新校验）

## 模型 qwen3:1.7b（千问，Ollama 官方模型库）

- 拉取命令：`ollama pull qwen3:1.7b`（来源 registry.ollama.ai/library/qwen3）
- 本地清单摘要（manifest digest）：`sha256:8f68893c685c3ddff2aa3fffce2aa60a30bb2da65ca488b61fff134a4d1730e7`
- 模型层：`sha256:3d0b790534fe4b79525fc3692950408dca41171676ed7e21db57af5c65ef6ab6`（1,359,279,776 字节）

## TikTok 取片工具 omniget-cli + yt-dlp（2026-11-06 加入，tiktok/ 目录用）

- omniget-cli（开源，OpenSelena/omniget，GPL-3.0）：
  - 仓库：https://github.com/OpenSelena/omniget
  - 锁定版本：v0.14.0，资产 `omniget-cli-0.14.0-x86_64-unknown-linux-gnu.tar.gz`（5,916,273 字节）
  - 下载：https://github.com/OpenSelena/omniget/releases/download/v0.14.0/omniget-cli-0.14.0-x86_64-unknown-linux-gnu.tar.gz
  - SHA-256：`ec29439b1928c0871592f5c10b758349dad01a5411950e00e46313f6617d0de4`
    （2026-11-05 本地下载文件实测比对；install-omniget.sh 每次安装都会重新校验）
  - 备注：二进制 `--version` 自报 0.1.0，是上游内部版本号没跟上，不影响使用。
- yt-dlp（omniget 的下载引擎，开源，yt-dlp/yt-dlp）：
  - 锁定版本：2026.10.26，资产 `yt-dlp`（zipapp，3,073,072 字节）
  - 下载：https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.26/yt-dlp
  - SHA-256：`e51e69e89489f199530f13d32a4342da3ddb2cf34842f364603a066db05afbf3`
    （与该 release 官方 SHA2-256SUMS 中 `yt-dlp` 一行一致）

## Windows 原生版资产（2026-11-08 加入，windows/ 目录用）

版本与 Linux 版锁定一致，资产换成各官方的 Windows x64 构建，全部带 SHA-256
（值取自官方 release 的 digest / 官方校验文件，windows/versions.psd1 同步锁定）：

- Ollama v0.40.14，资产 `ollama-windows-amd64.zip`（1,601,954,968 字节）
  - 下载：https://github.com/ollama/ollama/releases/download/v0.40.14/ollama-windows-amd64.zip
  - SHA-256：`65d68cade6cf6375f398b518224f8c8a15e062387f38cf477abfc848de7e7e29`
  - 备注：机器上已有 Windows 版 Ollama 时安装器直接复用，不下载此包。
- FFmpeg 8.1.2（Gyan 构建，ffmpeg.org 下载页链接的 Windows 构建方之一）：
  资产 `ffmpeg-8.1.2-essentials_build.zip`
  - 下载：https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-8.1.2-essentials_build.zip
  - SHA-256：`db580001caa24ac104c8cb856cd113a87b0a443f7bdf47d8c12b1d740584a2ec`
    （与同目录官方 `.sha256` 文件一致，2026-11-08 核对）
- omniget-cli v0.14.0，资产 `omniget-cli-0.14.0-x86_64-pc-windows-msvc.zip`（6,121,309 字节）
  - 下载：https://github.com/OpenSelena/omniget/releases/download/v0.14.0/omniget-cli-0.14.0-x86_64-pc-windows-msvc.zip
  - SHA-256：`0919da175a95528402dc0073d85e01bfb6d20402f1d10713ebece6e2156c068a`
- yt-dlp 2026.10.26，资产 `yt-dlp.exe`（23,575,744 字节）
  - 下载：https://github.com/yt-dlp/yt-dlp/releases/download/2026.10.26/yt-dlp.exe
  - SHA-256：`f5389d3698ecde4ef06f4e6b1ce0294fe9ac1396228c8990b8d3416d6d177a7d`

## 依赖

- ffmpeg（Hypit 必需）：目标机自带（本机 8.1.2）；缺失时 install.sh 尝试用 apt 安装。
- Node.js / npm / npx：Muse VM 自带（本机 node v24.22.1 / npm 10.9.4），脚本只做预检不代装。
- .tar.zst 解包：优先 `tar --zstd` 或 `zstd` 命令；都没有时脚本用 Python `zstandard`
  模块流式解包（`extract_zst.py`，即本机首次安装时实际用通的办法）。

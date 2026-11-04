# Hypit + Ollama + qwen3:1.7b 一键安装复刻包

把这套在 Muse 账号 A 上跑通的环境，原样搬到另一个 Muse 账号：
**Hypit（skill + CLI + 两套无头浏览器）+ 开源 Ollama + 千问 qwen3:1.7b 本地模型**，
全部从官方来源下载、版本锁定、Ollama 安装包带 SHA-256 校验。

> **完整文档看 [使用手册.md](使用手册.md)**：功能介绍、每个脚本的参数、
> 全流程场景、故障排查都在那一份里。本 README 只做快速上手。

## 一键安装

```bash
tar -xzf hypit-ollama-replication-kit.tar.gz
cd hypit-ollama-replication-kit
./install.sh
```

## 作为 GitHub 项目使用（仓库发布后）

这个文件夹本身就是一个完整的 git 仓库结构。发布到 GitHub 后，别人有两种装法：

```bash
# 方式一：克隆安装（推荐——之后 upgrade.sh 能直接在仓库目录里升级）
git clone https://github.com/<you>/hypit-ollama-kit.git
cd hypit-ollama-kit && ./install.sh

# 方式二：一行流（把 <you> 换成仓库主）
curl -fsSL https://raw.githubusercontent.com/<you>/hypit-ollama-kit/main/bootstrap.sh | KIT_REPO=<you>/hypit-ollama-kit bash
```

发布步骤：GitHub 上新建一个空仓库（如 `hypit-ollama-kit`，不要勾选初始化
README），然后在本目录执行 `git remote add origin <仓库地址>` + `git push -u origin main`。
本包不含任何账号、令牌或代理地址（代理在安装时从目标机环境读取），可安全公开；
脚本与文档以 MIT 发布（见 LICENSE），Hypit / Ollama / 模型本体都是安装时从
官方来源下载，不随仓库分发，各自遵循其上游许可。

装完脚本会自动跑一遍 `verify.sh`（含一次真实推理冒烟测试）。全程约需下载
**3.5 GB 左右**（Ollama 1.5G + 模型 1.4G + 浏览器约 0.6G），请预留至少 6.5 GB 磁盘。

脚本是**幂等**的：重复运行会跳过已装好的部分，只补缺失项——比如 Muse 的 VM
被替换后 `/etc` 下的 systemd 服务没了、但家目录里的二进制和模型还在，
重跑一次 `install.sh`（或单独跑 `bash setup-ollama-service.sh`）即可恢复。

## 复制到其他 Muse 账号的用法

1. 把 `hypit-ollama-replication-kit.tar.gz`（或整个文件夹）传到目标账号；
2. 把 `AGENT_PROMPT.md` 里的那段话发给那边的 Muse，它会自己解压、安装、验证并汇报；
3. 也可以自己在终端按上面的三行命令手动跑。

## TikTok 取片法也在包里（tiktok/ 目录）

- `tiktok/TIKTOK_METHOD.md` — 固定取片法全文：浏览器开 SaveFrom 页
  （zh.savefrom.net/105Ei/download-from-tiktok）粘链接下无水印 MP4、短链接
  （vt.tiktok.com）的解析办法、广告弹窗避坑、取片后拆解流程。这一步必须走
  真实浏览器（下载链接是网页在浏览器会话里现生成的），所以它是给 Muse/人
  照着做的方法文档，不是命令行脚本。
- `tiktok/prepare-reference.sh` — 下载之后的自动化：把下好的文件归档成标准
  拆解工程（`~/workspace/hypit-projects/<项目名>/`），自动生成规格/切点候选/
  音量报告和每 0.5 秒的帧网格证据图，拿来就能看帧拆解。

## 装完有什么

| 组件 | 位置 | 说明 |
|---|---|---|
| Hypit skill | `~/.agents/skills/hypit` | Muse 的技能目录，重启不丢 |
| Hypit CLI 0.3.1 | `~/.local/share/hypit-cli`，软链 `~/.local/bin/hypit` | 锁定版本，家目录安装 |
| 采集浏览器 | `~/.cache/puppeteer`（Chrome for Testing 153） | `hypit capture` 用 |
| 渲染浏览器 | `~/.cache/hypit`（Chrome Headless Shell 152） | Hypit 正式渲染管线用 |
| Ollama 0.40.14 | `~/ollama`，软链 `~/.local/bin/ollama` | 官方 release 包，校验过 SHA-256 |
| Ollama 服务 | systemd `ollama.service`，API `http://127.0.0.1:11434` | 当前环境的代理变量已写进服务单元（服务进程拉模型要用） |
| qwen3:1.7b | `~/.ollama/models` | 官方模型库拉取，约 1.4 GB |

使用前把软链目录加进 PATH（Muse 的终端通常已包含）：

```bash
export PATH="$HOME/.local/bin:$PATH"
hypit --version          # 0.3.1
curl http://127.0.0.1:11434/api/version
ollama list              # 应能看到 qwen3:1.7b
```

## 可选参数

```bash
./install.sh --check-only     # 只做环境预检，不安装
./install.sh --skip-browsers  # 跳过两套浏览器下载
./install.sh --skip-model     # 跳过拉模型
./install.sh --skip-smoke     # 跳过最后的推理冒烟测试
./install.sh --force          # 强制重装已存在的组件
bash verify.sh                # 随时单独复验（--no-smoke 跳过推理）
bash setup-ollama-service.sh  # VM 重启后单独恢复 Ollama 服务
./uninstall.sh --yes          # 卸载（默认保留 ~/.ollama 模型；加 --purge 连模型删）
```

版本都锁在 `versions.env` 里，升级时改那一个文件即可；来源与校验值见 `SOURCES.md`。

## 官方版本升级了怎么办

默认**不自动升级**——锁定版本是为了保证每个账号装出来的环境一模一样、且是
验证过的；官方大版本可能改命令或配置格式，闷头自动升容易把能用的环境升坏。
要升级时跑随包的升级脚本，一条命令走完：

```bash
./upgrade.sh --check   # 只查：当前锁定 vs 官方最新（不改任何东西）
./upgrade.sh           # 升级：刷新 versions.env 的版本与校验值 → 重跑安装 → 自动验证（含推理测试）
```

安全措施：升级前自动备份 `versions.env`（带时间戳），旧的 `~/ollama` 也会被
install.sh 改名保留；升级后验证不过，按脚本末尾打印的一行命令即可回滚到旧版。
三点细节：Hypit 的 skill 本身不单独锁版，升级时随仓库最新版重装；qwen3:1.7b
是浮动标签，"升级模型"=重新 pull 刷新摘要，`./upgrade.sh` 在版本无变化时也会
顺带做这一步；想换模型尺寸（如 4b）是改 `versions.env` 里的 `OLLAMA_MODEL`，
不自动跟随。

## 已知注意事项（都是实测踩过的）

- **全部装在家目录是故意的**：Muse VM 的根分区（/usr、/etc、apt 状态）在 VM
  替换后不保留，全局 npm 安装和 apt 装的 zstd 都被冲掉过；家目录才存活。
- **Ollama 服务必须带代理**：Muse 的出口代理只在 shell 里有不够，服务进程自己
  要联网拉模型——`setup-ollama-service.sh` 会把当前环境的 `http_proxy/https_proxy`
  等变量写进 systemd 单元。换了环境重跑该脚本即可刷新，脚本不会打印代理地址。
- **qwen3 要关思考模式**：默认 thinking 会把 token 预算耗光才回答；调 API 时带
  `"think": false`（`verify.sh` 的冒烟测试就是这么调的）。
- **`hypit capture screenshot` 在 root 下会失败**（该命令启 Chrome 没带
  `--no-sandbox`），但正式渲染管线自带该参数、不受影响，不挡生产。
- **`hypit programs prepare` 必须在工程里跑**：它要求当前目录是一个选定了
  Runtime 的 Hypit 工程，在空目录会直接报错。install.sh 用随包的最小示例工程
  （`smoke-project/`，含已验证的双端点 runtime 配置）代跑这一步；手动补装
  渲染浏览器时也请照此办理，不要在主目录直接跑。
  另注意 `runtime init` 新建的默认配置含一个需要 `uv` 的 opencv 端点，本包的
  配置只保留 media + html 两个已验证端点，不受影响。
- 本包只支持 **Linux x86_64**（在 Ubuntu 24.04 的 Muse VM 上验证）；Ollama 的
  锁定资产就是 linux-amd64 版。

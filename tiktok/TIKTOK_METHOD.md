# TikTok 参考视频取片法（omniget-cli 路线，用户改版 2026-11-06）

拿到一条 TikTok 链接要做参考/复刻时，固定按这套取片，不要另找野路子。
取片工具是 **omniget-cli**（开源项目 [OpenSelena/omniget](https://github.com/OpenSelena/omniget)
的命令行版，GPL-3.0，底层引擎 yt-dlp）：命令行直接下载，**不用开浏览器、
不用粘贴到第三方下载站**。2026-11-06 起取代旧的 SaveFrom 浏览器路线
（旧法保留在文末作兜底）。

## 工具安装

取片工具已包含在全套安装里：跑 `./install.sh` 时会一并装好
（可用 `--skip-omniget` 跳过）。单独补装/修复时跑一次：

```bash
bash tiktok/install-omniget.sh
```

它会从官方 GitHub Release 下载并校验 SHA-256（版本锁定在 `versions.env`）：

- omniget-cli 0.14.0 → `~/workspace/tools/omniget/omniget-cli`
  （二进制 `--version` 自报 0.1.0 是上游内部版本号没跟上，不碍事）
- yt-dlp 2026.10.26 → `~/.local/share/com.openselena.omniget/bin/yt-dlp`
  （必须手动放这一份：omniget 自带的引擎自动下载在 Muse VM 上失败，
  升级/重装时不要删这个文件）

## 取片步骤（一条命令）

```bash
bash tiktok/download-tiktok.sh "<TikTok链接>"
```

脚本依次做：`info` 报标题/作者/时长 → 下载到
`~/workspace/downloads/omniget/tiktok/` → ffprobe 验可播 → 打印文件路径
和下一步的归档命令。手动跑等价命令也可以：

```bash
CLI=~/workspace/tools/omniget/omniget-cli
$CLI info     --proxy "$HTTPS_PROXY" "<TikTok链接>"
$CLI download --proxy "$HTTPS_PROXY" -o ~/workspace/downloads/omniget/tiktok "<TikTok链接>"
```

要点（都是实测结论）：

- **代理铁律**：Muse VM 没有直连外网，下载**必须**带
  `--proxy "$HTTPS_PROXY"`（代理从环境变量读，不要把地址明文写进任何文件）。
  不带代理必失败，且报错会误写成 "extractor is broken"，其实是断网。
  在有直连网络、没有代理变量的机器上，去掉 `--proxy` 即可。
- **记录三样信息**备用：视频标题、作者账号、时长（`info` 会给出）。
- **失败先原样重试一次**（TikTok 是 omniget 支持的站里最稳的，
  2026-11-05 实测 info 约 6 秒返回、真实下载成功）。两次都失败，
  先排查代理，再考虑文末兜底路线，不要无限重试。
- TikTok 下载件常见 HEVC 编码，ffprobe 能验可播即可；后续交给
  Hypit 拆解管线处理，不要在这里转码。

## 短链接处理

用户给的常是短链（如 `https://vt.tiktok.com/XXXX/`）：omniget/yt-dlp
**能直接解析短链**，不用再像旧法那样先开浏览器跳转取长链。下好后把
规范地址（`tiktok.com/@作者/video/视频ID`，info 里能看到）和视频 ID
记进拆解文档。

## 下载之后（脚本化部分）

把下好的文件交给归档脚本（项目名用英文短横线，如 `agris-street-run`）：

```bash
bash tiktok/prepare-reference.sh <下载好的文件.mp4> <项目名>
```

它会在 `~/workspace/hypit-projects/<项目名>/` 下建好标准结构并生成拆解证据：

```
<项目名>/
├── references/
│   ├── source.mp4            # 原片（统一改这个名）
│   └── PROBE.txt             # 规格 + 切点候选 + 音量（hypit probe/boundaries 实测）
└── evidence/tiles/           # 每 0.5 秒一张的带时间码帧网格图
```

## 拆解流程（取片之后做什么）

1. **看完整个视频**：逐张看完帧网格图（0.5s 一格），需要时对关键段加密抽帧；
2. 写 `references/TIMELINE.md`（逐段时间轴）和 `references/ANALYSIS.md`
   （内容读法、视觉系统、声音、换角/复刻要点）；
3. 产出提示词包（主提示词中英双版 + 分镜版 + 锁定块 + 负面词 + 生产说明）；
4. 边界候选（boundaries）只是"画面变化点"，不是镜头切点结论——是否切镜要靠看帧确认；
5. `hypit media tiles` 有个已知坑：采样终点顶到视频总时长会报
   "no video frame exists"，prepare-reference.sh 已用"总时长 −0.1s"规避，手动跑时记得。

## 兜底路线（omniget 两次失败时才用，旧 SaveFrom 法）

浏览器打开 https://zh.savefrom.net/105Ei/download-from-tiktok ，粘链接，
选 MP4 无水印下载；广告弹窗、假按钮、装扩展/APP 提示一律关掉，不装任何
东西、不注册、不登录。短链解析失败时先在浏览器打开短链取规范长链再粘。
这条路依赖真实浏览器会话，只作兜底，日常不要走。

## 已实测记录

- 2026-11-05：omniget-cli v0.14.0 在本机实测——TikTok info 约 6 秒返回，
  @mr.whiskerzlovesyou《橱窗馋猫》原片（17.67s，720×1280，HEVC）真实
  下载成功并 ffprobe 验可播；同批测试 B站（免登录 1080p）、YouTube 亦通。
- 2026-11-06：用户拍板把复刻包的 TikTok 取片法由 SaveFrom 浏览器路线
  改为 omniget-cli 路线；本文件、`install-omniget.sh`、
  `download-tiktok.sh` 即为改版结果，SaveFrom 降为兜底。
- 历史（旧法）：2026-11-04 SaveFrom 路线定版并多次成功取片
  （@agris_red 滑板片、@meisheanran1122 西瓜片等）。

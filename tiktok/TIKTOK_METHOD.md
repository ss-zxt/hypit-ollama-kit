# TikTok 参考视频取片法（SaveFrom 路线，用户定版 2026-11-04）

拿到一条 TikTok 链接要做参考/复刻时，固定按这套取片，不要另找野路子。
这一步**必须走真实浏览器**：SaveFrom 的下载链接是它网页在浏览器会话里现生成的，
普通命令行抓取拿不到——所以取片动作由操作浏览器的 Muse（或人）完成；
下载完成之后的归档与拆解证据生成，用同目录的 `prepare-reference.sh` 一键做掉。

## 取片步骤

1. 浏览器打开：https://zh.savefrom.net/105Ei/download-from-tiktok
   （页面标题「下载TikTok视频 - 免费无水印」，中间有粘贴框和绿色「下载」按钮）
2. 把 TikTok 链接粘进输入框（占位文字「在这里粘贴视频链接」），点绿色「下载」。
3. 结果区选 **MP4 无水印**，有高清选高清；点下载，等文件完整落盘。
4. 途中弹出的广告页、假下载按钮、装扩展/APP 的提示一律关掉：**不装任何东西、
   不注册、不登录**。
5. 记录三样信息备用：视频标题、作者账号、时长（结果区会显示）。

## 短链接处理

用户给的常是短链（如 `https://vt.tiktok.com/XXXX/`）。SaveFrom 一般能直接解析；
若解析失败：先在浏览器打开短链本身，等它跳转到 `tiktok.com/@作者/video/视频ID`
的规范地址，复制那条长链接再回 SaveFrom 粘贴。规范地址和视频 ID 要记进拆解文档。

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

## 已实测记录

- 2026-11-04：页面可用性验证通过；@agris_red 滑板片（15s）经此路成功取片拆解。
- 2026-11-04：短链 vt.tiktok.com 经 SaveFrom 直接解析成功（@meisheanran1122
  西瓜片，无水印 MP4 720），短链处理分支同时留档备用。

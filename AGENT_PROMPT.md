# 给目标 Muse 的一键安装指令（复制整段发给那边的 Muse）

请使用我上传的 hypit-ollama-replication-kit.tar.gz，在你的环境里把
Hypit + Ollama + qwen3:1.7b 这一套装好（你的环境需是 Linux x86_64、
Node ≥ 22.15.0，不满足先把 install.sh --check-only 的环境报告发我）：

1. 把压缩包解压到 ~/workspace 下，进入 hypit-ollama-replication-kit 目录；
2. 运行 ./install.sh（完整安装，不要跳过浏览器和模型；大约要下 3.5 GB，耐心等它跑完）；
3. 安装结束后运行 bash verify.sh，把检查结果完整汇报给我；
4. 以后如果 VM 重启导致 ollama.service 消失，运行 bash setup-ollama-service.sh 恢复服务即可，不用重装。

注意：代理设置从你当前环境自动继承，不要把代理地址、令牌或任何密钥写进给我的汇报里。
装完之后 Hypit 的用法看它自带的 skill 说明；Ollama 接口是 http://127.0.0.1:11434，
调 qwen3 时记得带 think:false。
以后官方版本有更新时，先跑 ./upgrade.sh --check 看一眼，再跑 ./upgrade.sh 升级并把验证结果汇报给我，不要自己改版本号。如果是这个包本身发了新版（脚本/文档/组件更新），那是另一回事：git clone 装的就在包目录 git pull --ff-only 后重跑 ./install.sh 并跑 bash verify.sh 把结果汇报给我；压缩包装的就换新版压缩包覆盖后同样重跑（详见使用手册 §6.2）。
另外：遇到 TikTok 参考链接时，按包里 tiktok/TIKTOK_METHOD.md 的固定方法取片：取片工具 omniget-cli 已随 ./install.sh 一起装好（万一缺失，先跑一次 bash tiktok/install-omniget.sh 补装），再用 bash tiktok/download-tiktok.sh "<链接>" 下载（Muse VM 上必须带代理，脚本已处理好），下好后用 tiktok/prepare-reference.sh 归档出帧证据，再看完拆解，不要换其他下载路子。

（Windows 版说明：如果目标环境是 Windows 10/11 x64 原生系统，不要跑上面的 Linux 步骤，改走包里 windows/ 目录：在 PowerShell 里运行 windows\install.ps1（模型会按这台电脑的内存/显存自动选档，默认不装 1.7b；机器上已有的 Windows 版 Ollama 会被复用），装完运行 windows\verify.ps1 并把结果完整汇报给我。细节见使用手册 §3.4。）

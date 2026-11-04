# 给目标 Muse 的一键安装指令（复制整段发给那边的 Muse）

请使用我上传的 hypit-ollama-replication-kit.tar.gz，在你的环境里把
Hypit + Ollama + qwen3:1.7b 这一套装好：

1. 把压缩包解压到 ~/workspace 下，进入 hypit-ollama-replication-kit 目录；
2. 运行 ./install.sh（完整安装，不要跳过浏览器和模型；大约要下 3.5 GB，耐心等它跑完）；
3. 安装结束后运行 bash verify.sh，把检查结果完整汇报给我；
4. 以后如果 VM 重启导致 ollama.service 消失，运行 bash setup-ollama-service.sh 恢复服务即可，不用重装。

注意：代理设置从你当前环境自动继承，不要把代理地址、令牌或任何密钥写进给我的汇报里。
装完之后 Hypit 的用法看它自带的 skill 说明；Ollama 接口是 http://127.0.0.1:11434，
调 qwen3 时记得带 think:false。
以后官方版本有更新时，先跑 ./upgrade.sh --check 看一眼，再跑 ./upgrade.sh 升级并把验证结果汇报给我，不要自己改版本号。

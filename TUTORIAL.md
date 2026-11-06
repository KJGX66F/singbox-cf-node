# 完整部署教程：CF + sing-box + 伪装网页 VLESS 节点

> 跟着做下来约 5–10 分钟。基础版不需要域名、不花钱；进阶版再套 Cloudflare。
> ⚠️ 本项目开源免费，**仅供学习、练习与参考，严禁任何商业使用**。
> 仓库：`KJGX66F/singbox-cf-node`（公开后任何人可直接选用）

## 先准备好三样东西

1. **GitHub 账号**（用来在部署时选择本仓库）；
2. **Cloady 账号**：打开 cloady.com，用邮箱收 6 位验证码登录（没有密码，不用银行卡）；
3. **一个代理客户端**：v2rayN（电脑）/ Shadowrocket 小火箭（iOS）/ FlClash 或 v2rayNG（安卓），任选其一。**请用这四个之一**：经实测，平台边缘会改写一个握手响应头，sing-box 内核的客户端（如 SFA、Hiddify、NekoBox）会因此握手失败；上面四个（xray / mihomo 内核）不受影响。

## 第一步：建工作区（已有可跳过）

登录 Cloady 后新建 Workspace，区域选**永久免费区**之一：JPN1（日本）、EU1（欧洲）、USW1（美西）、USE1（美东）。免费额度是 0.5 vCPU / 1 GB 内存，一个节点正好用满，不花钱。

## 第二步：部署应用

1. 在工作区点 **New application**；
2. 选 **Connect GitHub account**，授权后选中 **singbox-cf-node** 仓库（自己的账号先 Fork 一份也可以）；
3. 平台会自动识别仓库里的 Dockerfile / Compose，保持默认，点部署；
4. 等待构建完成（约 2–5 分钟），状态变 **Running**。

## 第三步：填环境变量（最关键，别漏）

进入应用的 **Settings → Environment**，添加三个变量：

| 变量 | 填什么 |
|---|---|
| `UUID` | 自己生成一个新的（在线搜「UUID 生成器」或用命令 `cat /proc/sys/kernel/random/uuid`），**不要照抄任何教程里的** |
| `WS_PATH` | 自己想一个猜不到的路径，如 `/stream-xxxxxx`（把 x 换成随机字母数字） |
| `PORT` | `3000` |

保存后点 **Redeploy** 重新部署一次——**改完环境变量必须重新部署才生效**，这是最常见的翻车点。

## 第四步：拿到应用地址

回到应用主页，记下平台分配的地址，形如：

```
https://app-xxxxxxxx-workspace-xxxxxx.cloady.io
```

## 第五步：自检（30 秒）

用浏览器打开：

1. **应用地址本身** → 看到流浪狗救助站页面 = 伪装层正常 ✅
2. **应用地址 + 你的 WS_PATH**（如 `https://app-…cloady.io/stream-xxxxxx`）→ 显示 `Bad Request` 或 400 = sing-box 在应答 ✅

两个都对，服务端就部署成功了。

## 第六步：打开取链接页面，一键导入

用浏览器打开 `https://<应用地址>/<你的 UUID>`（后缀就是你第一步填的那个 UUID，它本来就是节点的钥匙），页面会自动拼好你的节点链接：

1. 点页面上的 **Copy link**；
2. 打开客户端（v2rayN / v2rayNG / 小火箭 / FlClash），选「从剪贴板导入」；
3. 选中节点开启，验证能打开网页、出口地区与所选区域一致。

> 这个页面地址和 UUID 一样是钥匙，别发给任何人、别让它入镜。
> 备用方法（页面打不开时才用）：手工拼链接——把下面链接里的占位符换成你自己的值：

```
vless://<UUID>@<应用地址>:443?encryption=none&security=tls&sni=<应用地址>&type=ws&host=<应用地址>&path=<WS_PATH 做 URL 编码>#Singbox-Node
```

- `<应用地址>` 不要带 `https://`，只填域名部分，如 `app-xxxx-workspace-xxxx.cloady.io`；
- `path` 要做 URL 编码：`/` 写成 `%2F`，例：WS_PATH 是 `/stream-abc123` → path 填 `%2Fstream-abc123`。

导入后开启代理，验证两件事：① 能正常打开网页；② 查 IP 显示的地区与你选的区域一致（如 JPN1 显示日本）。

## 附：想用「镜像部署」？先让 Actions 打包你自己的镜像

第二步选的是连 GitHub、由平台构建；如果你想在新建应用时选 **Deploy a Docker image**（填镜像地址那种），镜像要用你自己的，按下面做一遍：

1. 把仓库 **Fork** 到你的 GitHub 账号；
2. 打开 Fork 的 **Actions** 页，点启用工作流（Fork 默认禁用，只需点一次）；
3. 选 **Build Docker image → Run workflow**，等它跑绿（约 2–3 分钟）；
4. 到仓库的 **Packages**，点开 `singbox-cf-node` 包，在 Package settings 里把可见性改成 **Public**；
5. 回 Cloady 新建应用选 **Deploy a Docker image**，镜像地址填 `ghcr.io/<你的 GitHub 用户名>/singbox-cf-node:latest`，其余步骤（填环境变量、Redeploy、自检）与正文相同。

## 进阶（可选）：套 Cloudflare

有自己域名的再做这段，没域名不影响使用：

1. 把域名托管到 Cloudflare（改 NS，免费套餐即可）；
2. 在 Cloady 应用设置里绑定你的自定义域名（如 `node.example.com`），等它签好证书；
3. Cloudflare DNS 里加一条 CNAME：`node` 指向你的应用地址，**开启橙云代理**；
4. Cloudflare 的 SSL/TLS 模式先选 **Flexible** 跑通（源站证书就绪后可改 Full）；
5. 客户端链接里的地址、sni、host 全部换成你的域名，其余不变；
6. **优选加速**：再复制一条链接，地址换成 Cloudflare 优选 IP（sni/host 仍填域名），与域名版对比实测，留快的那条。

> 说明：这一段涉及你自己的域名与 Cloudflare 账号，仓库作者无法替你验证你的具体配置；直连版先跑通再套 CF，出问题也好定位。

## 常见问题

| 现象 | 原因与解法 |
|---|---|
| 构建失败 | 看应用 Deploy 日志；多为网络拉取镜像失败，点 Redeploy 重试 |
| 伪装站打不开 / 地址 404 | 先等 2–3 分钟（新应用地址生效有延迟）；确认应用是 Running |
| 改了变量没变化 | 没 Redeploy，重新部署一次 |
| 客户端测速 -1 / 超时 | 逐项核对：UUID、WS_PATH、链接里 path 的 `%2F` 编码、host 与 sni 是否一致 |
| 几天后节点停了 | 免费应用 7 天无流量会自动暂停，去 Cloady 后台点 **Start** 恢复 |
| 打开 WS 路径不是 400 | 路径填错了，或变量没生效（回第三步检查 + Redeploy） |

## 安全提醒

- `UUID` 和 `WS_PATH` 就是节点的全部钥匙，不要发给任何人、不要出现在截图和视频里；
- 录教程演示时，请用一套一次性的演示参数，录完删掉那个应用；
- 本项目仅供个人学习与自用，请遵守部署平台的服务条款。

# CF + sing-box + 伪装网页的高速 VLESS 节点

一个容器搞定：**sing-box（VLESS + WebSocket）藏在一个正经网站后面，前面再套 Cloudflare CDN**。

- 打开域名看到的是一个流浪狗救助站网页（伪装网页），不知道秘密路径的人看不出任何异常；
- 只有带对路径的 WebSocket 请求才会被转给 sing-box；
- 流量走 Cloudflare 边缘，客户端还可以填「优选 IP」进一步提速；
- UUID、路径、端口全部用环境变量配置，不写死在代码里。

> ⚠️ **开源免费声明**：本项目开源免费发布，**仅供学习、练习与参考，严禁任何商业使用**（包括但不限于收费部署、打包售卖、作为付费服务的一部分、商用引流）。详见 [LICENSE](LICENSE)。

## 工作原理

```
客户端 ──TLS──▶ Cloudflare（橙云代理）──▶ 容器 :3000（Caddy）
                                              ├─ 普通路径 → 伪装站（流浪狗救助主题静态站）
                                              └─ $WS_PATH → 反代到 sing-box (127.0.0.1:10000)
                                                              VLESS + WS 出站直连
```

## 环境变量

| 变量 | 必填 | 默认 | 说明 |
|---|---|---|---|
| `UUID` | ✅ | 无 | 节点 UUID，自己生成一个（`cat /proc/sys/kernel/random/uuid`） |
| `WS_PATH` | | `/ray` | 秘密路径，**务必改**成别人猜不到的，如 `/a8f3-media-stream` |
| `PORT` | | `3000` | 容器对外端口（平台要求多少就填多少） |

## 部署方式一：Docker 镜像（平台选「Deploy a Docker image」）

镜像用你自己的——本仓库自带 GitHub Actions 工作流，Fork 后自动打包到**你自己的** GHCR，全程不用装 Docker：

1. 把本仓库 **Fork** 到你的 GitHub 账号；
2. 打开你 Fork 的 **Actions** 页，点一次启用工作流（Fork 的仓库默认禁用 Actions，必须手动开一次）；
3. 选 **Build Docker image → Run workflow**（或随便推送一次提交），等它跑绿；
4. 镜像生成在 `ghcr.io/<你的用户名>/singbox-cf-node:latest`；再到 **Packages** 里把这个包的可见性改为 **Public**（部署平台免密拉取需要）；
5. 在部署平台创建应用时填**你自己的**镜像地址，设置环境变量 `UUID`、`WS_PATH`、`PORT`。

（也可以本地 `docker build` 后推到任意公共仓库，效果一样。）
3. 记下平台给应用分配的公网地址。

本地自检：

```bash
cp .env.example .env   # 填好 UUID
docker compose up -d
curl -I http://127.0.0.1:3000/        # 200，伪装站
```

## 部署方式二：上传源码（平台选 Upload / Compose）

把本仓库文件（Dockerfile、Caddyfile、entrypoint.sh、site/、docker-compose.yml）打包上传，平台会按 Dockerfile 构建；同样设置好三个环境变量即可。

## Cloudflare 设置（关键）

1. 域名托管到 Cloudflare，给节点加一条 DNS 记录（如 `node.example.com`）指向平台给的公网地址，**开启橙云代理**。
2. SSL/TLS 模式：
   - 平台只给 HTTP 入口 → 用 **Flexible**（CF 到源站走 HTTP，先跑通）；
   - 平台给源站配了证书 → 用 **Full (Strict)**（更推荐）。
3. 确认所选套餐支持 WebSocket（免费版支持，无需额外设置）。

## 获取节点链接（推荐：取链接页面）

部署成功后，用浏览器打开（后缀就是你的 UUID，它本来就是节点的钥匙，不用再多记一个）：

```
https://<你的地址>/<你的 UUID>
```

页面会自动拼好完整的节点链接，点 **Copy link**，再到客户端里选「从剪贴板导入」即可，不用再手工拼参数。**不要把这个页面地址发给任何人、不要让它出现在截图和视频里**——打开它的人就能拿到完整链接。

手工拼链接（备用）：

```
vless://<UUID>@<你的域名>:443?encryption=none&security=tls&sni=<你的域名>&type=ws&host=<你的域名>&path=<WS_PATH 的 URL 编码>#CF-Singbox
```

例：WS_PATH 为 `/a8f3-media-stream` 时 path 填 `%2Fa8f3-media-stream`。

**优选加速**：把链接里的地址换成 Cloudflare 优选 IP（域名仍填在 sni/host 里），是这套方案常见的提速手法；稳定性因地区和运营商而异，建议与直连域名各存一条对比实测。

## 安全与边界

- `UUID` 和 `WS_PATH` 就是全部凭证，泄露等于节点公开；
- 伪装网页只是「看起来正常」，不提供额外的加密强度；真正的保密来自 TLS + UUID；
- 请遵守部署平台的服务条款，本项目仅供个人学习与自用；
- 免费平台的流量/请求额度各不相同，注意控制台的用量提醒。

## 文件清单

| 文件 | 作用 |
|---|---|
| `Dockerfile` | 单容器镜像：Caddy（前门）+ sing-box（内核） |
| `.github/workflows/` | 打包工作流：Fork 后经 Actions 构建镜像并推到你自己的 GHCR |
| `Caddyfile` | 伪装站 + WS 路径反代规则 |
| `entrypoint.sh` | 按环境变量生成 sing-box 配置、取链接页面，并拉起两个进程 |
| `sub-template.html` | 取链接页面的模板（运行时按 UUID/路径渲染到秘密后缀下） |
| `site/` | 伪装网页（可换成你自己的静态站） |
| `docker-compose.yml` | 本地/Compose 部署 |

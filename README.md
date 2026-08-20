# nezha-alpine

Nezha Monitoring 的 Alpine 移植版：**GitHub Actions 交叉编译 musl 静态二进制**，配套 **OpenRC** 部署，面向低配 Alpine 主机（1 核 / ~128MB 内存 / 无 systemd 的容器）。

## 构建（GitHub Actions 自动完成）

- 上游源码：`nezhahq/nezha`（dashboard）`v2.3.7` + `nezhahq/agent` `v2.3.3`
- dashboard：`CGO_ENABLED=1 CC=x86_64-linux-musl-gcc -tags go_json -extldflags "-static -fpic"`，前端（admin/user 主题）经 `go:embed` 内嵌进单文件二进制，**无需额外 resource 目录**
- agent：`CGO_ENABLED=0` 纯静态
- 产物发布到 Release tag `alpine`（每次构建覆盖）：
  - `dashboard-linux-amd64`
  - `nezha-agent-linux-amd64`
  - `checksums.txt`
  - `deploy.sh`（目标机一键部署）

手动触发：仓库 Actions 页 → **Build musl binaries** → Run workflow。

本地复现：`bash build.sh`（需 go 1.26+、musl-gcc、yq、curl、unzip）。

## 部署（目标 Alpine 主机）

```sh
wget -qO deploy.sh https://github.com/linseeee/nezha-alpine/releases/download/alpine/deploy.sh
sh deploy.sh                      # 仅 dashboard
sh deploy.sh <agent_secret>       # dashboard + agent 同机
```

- dashboard 监听 `0.0.0.0:8008`（gRPC 同端口复用），数据目录 `/opt/nezha/dashboard/data/`（sqlite）
- 首次登录 `admin/admin`，登录后立即改密
- agent 配置 `/opt/nezha-agent/config.yml`，`server: 127.0.0.1:5555`（同机直连，无 TLS）
- 低配优化已默认开启：`disable_auto_update` / `disable_command_execute` / `skip_connection_count` / `skip_procs_count`

## 目录

```
.github/workflows/build.yml  # Actions 构建 + 发布
build.sh                     # 本地可复现构建脚本
deploy/
  deploy.sh                  # 目标机一键部署（自包含）
  init.d/                    # OpenRC 服务模板
  config.dashboard.yaml      # dashboard 配置模板
  config.agent.yml           # agent 配置模板
```

## 内存提示

容器配额约 122MB 时，dashboard + agent 可跑但偏紧；建议宿主把配额提到 256MB 更稳。
公网访问需在宿主机放行 8008 端口（Agent 同端口走 gRPC）。

# nezha-alpine

Nezha Monitoring 的 Alpine 移植版：**GitHub Actions 交叉编译静态二进制**，配套 **OpenRC** 部署，面向低配 Alpine 主机（1 核 / ~128MB 内存 / 无 systemd 的容器）。

## 构建（GitHub Actions 自动完成）

- 上游源码：`nezhahq/nezha`（dashboard）`v2.3.7` + `nezhahq/agent` `v2.3.3`
- 构建环境与上游 release 完全一致：`goreleaser/goreleaser-cross:v1.26` 容器 + `CC=x86_64-linux-gnu-gcc` + `-extldflags "-static -fpic"`（静态链接，可在 Alpine/musl 环境直接运行）
- dashboard 前端（admin/user 主题）经 `go:embed` 内嵌进单文件二进制，**无需额外 resource 目录**；swagger docs 由 `swag init` 生成
- agent：`CGO_ENABLED=0` 纯静态
- 产物发布到 Release tag `alpine`（每次构建覆盖）：
  - `dashboard-linux-amd64`
  - `nezha-agent-linux-amd64`
  - `checksums.txt`
  - `deploy.sh`（目标机一键部署）

手动触发：仓库 Actions 页 → **Build static binaries** → Run workflow。

本地复现：`bash build.sh`（需 go 1.26+、musl-gcc、yq、curl、unzip）。

> 注意：首次尝试用 ubuntu 自带 gcc 编译的产物在 Alpine 上 Segfault，改用上游同款 goreleaser-cross 工具链后正常 —— 如需自定义构建环境，请以官方 release.yml 为基准。

## 部署（目标 Alpine 主机）

```sh
wget -qO deploy.sh https://github.com/linseeee/nezha-alpine/releases/download/alpine/deploy.sh
sh deploy.sh <agent_secret>   # dashboard + agent 同机（secret 为 dashboard 配置的 agent_secret_key）
```

- dashboard 监听 `0.0.0.0:8008`（HTTP 与 gRPC 同端口复用），数据目录 `/opt/nezha/dashboard/data/`（sqlite）
- 首次登录 `admin/admin`，登录后立即改密
- agent 配置 `/opt/nezha-agent/config.yml`：`server: 127.0.0.1:8008`、`client_secret` = dashboard 的 `agent_secret_key`、`uuid` 自定义（v2 中 agent 首次连接会自动注册服务器）
- 低配优化已默认开启：`disable_auto_update` / `disable_command_execute` / `skip_connection_count` / `skip_procs_count` / `report_delay: 4`

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

## 实测数据（目标机：1 核 / 128MB 容器配额 / Alpine 3.23.5）

- dashboard RSS ≈ 39MB，agent RSS ≈ 15MB，容器整体 ≈ 90MB / 128MB（余量 ~32MB）
- 磁盘占用：二进制 + sqlite ≈ 50MB（ZFS 压缩后）

## 内存提示

128MB 配额可跑但偏紧；建议宿主把配额提到 256MB 更稳。
公网访问需在宿主机放行 8008 端口（Agent 同端口走 gRPC）。

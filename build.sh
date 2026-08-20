#!/usr/bin/env bash
# 本地可复现的 musl 静态构建脚本（与 .github/workflows/build.yml 等价）
# 依赖: git, go 1.26.x, musl-gcc (musl-tools), yq, curl, unzip, bash
set -euo pipefail

NZHA_VERSION="${NZHA_VERSION:-v2.3.7}"
AGENT_VERSION="${AGENT_VERSION:-v2.3.3}"
OUT="${OUT:-$(pwd)/dist}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$OUT"

echo "==> clone upstream (dashboard $NZHA_VERSION, agent $AGENT_VERSION)"
git clone --depth 1 --branch "$NZHA_VERSION" https://github.com/nezhahq/nezha.git "$WORK/nezha"
git clone --depth 1 --branch "$AGENT_VERSION" https://github.com/nezhahq/agent.git "$WORK/agent"

echo "==> fetch frontend dists (embedded)"
(cd "$WORK/nezha" && bash script/fetch-frontends.sh)

echo "==> build dashboard (musl static)"
(cd "$WORK/nezha" && \
 CGO_ENABLED=1 CC="${CC:-x86_64-linux-musl-gcc}" go build -trimpath -buildvcs=false -tags go_json \
   -ldflags "-s -w -X github.com/nezhahq/nezha/service/singleton.Version=${NZHA_VERSION} -extldflags '-static -fpic'" \
   -o "$OUT/dashboard-linux-amd64" ./cmd/dashboard)

echo "==> build agent (pure static)"
(cd "$WORK/agent" && \
 CGO_ENABLED=0 go build -trimpath -buildvcs=false \
   -ldflags "-s -w -X github.com/nezhahq/agent/pkg/monitor.Version=${AGENT_VERSION}" \
   -o "$OUT/nezha-agent-linux-amd64" ./cmd/agent)

echo "==> checksums"
(cd "$OUT" && sha256sum dashboard-linux-amd64 nezha-agent-linux-amd64 | tee checksums.txt)
echo "==> done: $OUT"

#!/bin/bash
# ============================================================================
#  在 Docker 里构建 WangLinux amd64 ISO（Windows / macOS 装了 Docker Desktop 就能用）
#  用法：
#    1) 把 build-wanglinux-amd64.sh 和本文件放在同一个目录
#    2) Windows: 打开 PowerShell → bash build-in-docker.sh
#       macOS/Linux: bash build-in-docker.sh
#    3) 完成后 ISO 出现在 ./out/ 目录
# ============================================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-$HERE/out}"
mkdir -p "$OUT"

echo "[WangLinux] 输出目录: $OUT"
echo "[WangLinux] 容器内构建需 8-15 GB 磁盘、1.5-2.5 GB 下载流量"

docker run --rm -it --privileged \
  -v "$OUT:/build" \
  -v "$HERE/build-wanglinux-amd64.sh:/build-src/build.sh:ro" \
  -e WORK=/build/wanglinux-iso \
  debian:bookworm \
  bash -c "apt-get update -qq && apt-get install -y -qq bash ca-certificates && bash /build-src/build.sh"

echo
echo "[WangLinux] 完成。ISO:"
ls -lh "$OUT"/*.iso "$OUT"/*.sha256 2>/dev/null || echo "（没找到 ISO，请检查上面的日志）"

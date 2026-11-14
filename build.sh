#!/bin/bash
# ============================================================================
#  WangLinux 统一构建入口 —— 一个命令产出所有安装形态
#
#  用法：
#    ./build.sh <目标> [选项]
#
#  目标（安装形态）：
#    iso           x86_64 可启动 U 盘 / ISO（UEFI+BIOS 双启动）
#    qcow2         云镜像（qcow2，含 cloud-init，amd64/arm64）
#    rootfs        通用 rootfs tarball（amd64/arm64/armhf/riscv64）
#    container     OCI 容器镜像 tar（amd64/arm64）
#    wsl           Windows WSL 导入包（amd64）
#    arm64-image   通用 arm64 可烧录镜像（UEFI 板卡 / ARM 服务器）
#    pi            树莓派专用镜像（Pi 3/4/400/CM4）
#    deb           只构建全部 .deb 软件包（不建仓库）
#    repo          构建 .deb + 重建签名 apt 仓库
#    all           依次产出全部安装形态（较耗时）
#
#  通用环境变量：
#    ARCH=arm64       目标架构（rootfs/qcow2/container 等支持）
#    FLAVOR=desktop   桌面 / server 变体（arm64-image、container 等支持）
#    OUT=./out        输出目录
#    WL_MIRROR=...    覆盖默认 debootstrap 镜像源
#    WL_REPO_URL=...  覆盖 wanglinux apt 仓库地址
#
#  示例：
#    ARCH=arm64 ./build.sh qcow2
#    FLAVOR=desktop ./build.sh arm64-image
#    ./build.sh deb
# ============================================================================
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export OUT="${OUT:-$ROOT/out}"

run() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; bash "$@"; }

case "${1:-}" in
  iso)         run "$ROOT/builder/amd64-iso/build-wanglinux-amd64.sh" ;;
  qcow2)       run "$ROOT/builder/qcow2/build-qcow2.sh" ;;
  rootfs)      run "$ROOT/builder/rootfs/build-rootfs.sh" ;;
  container)   run "$ROOT/builder/container/build-container.sh" ;;
  wsl)         run "$ROOT/builder/wsl/build-wsl.sh" ;;
  arm64-image) run "$ROOT/builder/arm64/build-arm64-image.sh" ;;
  pi)          run "$ROOT/pi/assemble.sh" ;;
  deb)
    SRC="${SRC:-$ROOT/distro/pkgsrc}" OUT="$OUT/debs" \
      SIGN=no bash "$ROOT/distro/pkgsrc/build-repo.sh" ;;
  repo)
    SRC="${SRC:-$ROOT/distro/pkgsrc}" OUT="$OUT/repo" \
      bash "$ROOT/distro/pkgsrc/build-repo.sh" ;;
  all)
    "$0" rootfs && "$0" container && "$0" wsl && "$0" qcow2 && "$0" arm64-image ;;
  ""|-h|--help|help)
    sed -n '2,34p' "$0"
    exit 0 ;;
  *)
    echo "未知目标: $1" >&2
    sed -n '2,34p' "$0"
    exit 1 ;;
esac

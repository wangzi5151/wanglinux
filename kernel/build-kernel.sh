#!/bin/bash
# ============================================================================
#  WangLinux 内核构建套件 —— 产出 linux-image-*-wanglinux*.deb
#  运行环境：Debian 12 或 Ubuntu 22.04+ 物理机/VM（≥4 核、≥4 GB 内存、≥20 GB 磁盘）
#  耗时：约 40-90 分钟（4 核）
#  说明：这颗手机的 arm64 沙盒里无法在合理时间内完成内核编译，
#        因此本套件必须在真实机器上执行 —— 不假装能在这里跑完。
# ============================================================================
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

BRAND="${BRAND:-wanglinux}"
LOCALVERSION="${LOCALVERSION:--${BRAND}1}"
JOBS="${JOBS:-$(nproc)}"
BUILDROOT="${BUILDROOT:-/build/kernel}"
CONFIG_SRC="${CONFIG_SRC:-}"      # 可选：基于某个已存在的 config 文件
DIST="${DIST:-bookworm}"
MIRROR="${MIRROR:-http://mirrors.ustc.edu.cn/debian}"

log() { printf '\n\033[1;35m[kernel]\033[0m %s\n' "$*"; }
[ "$(id -u)" -eq 0 ] || { echo "请用 root 运行"; exit 1; }

# ---------------------------------------------------------------- 依赖 ----
log "安装构建依赖"
apt-get update -qq
apt-get install -y --no-install-recommends \
  build-essential bc bison flex libssl-dev libelf-dev libncurses-dev \
  dwarves zstd xz-utils kmod cpio rsync git wget ca-certificates dpkg-dev \
  >/tmp/wl-kernel-deps.log 2>&1 || { echo "依赖安装失败，见 /tmp/wl-kernel-deps.log"; exit 1; }

# ------------------------------------------------------------ 源码 ----
mkdir -p "$BUILDROOT"; cd "$BUILDROOT"
if ! ls -d linux-*/ >/dev/null 2>&1; then
  log "获取内核源码（推荐用 Debian 源码包，便于沿用其安全配置）"
  if grep -q "^deb-src" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    apt-get source linux >/tmp/wl-kernel-src.log 2>&1 || true
  fi
  if ! ls -d linux-*/ >/dev/null 2>&1; then
    log "改用 kernel.org 主线源码"
    MAJOR="${MAJOR:-6.12}"
    FULL=$(wget -qO- "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR%%.*}.x/" \
           | grep -oE "linux-${MAJOR}(\.[0-9]+)?\.tar\.xz" | sort -V | tail -1)
    [ -n "$FULL" ] || { echo "无法确定内核版本，请手动下载"; exit 1; }
    wget -c "https://cdn.kernel.org/pub/linux/kernel/v${MAJOR%%.*}.x/$FULL"
    tar -xf "$FULL"
  fi
fi
cd linux-*/
SRCVER=$(make -s kernelversion 2>/dev/null || echo unknown)
log "源码版本：$SRCVER"

# ------------------------------------------------------------ 配置 ----
log "写入 WangLinux 品牌与配置"
if [ -n "$CONFIG_SRC" ] && [ -f "$CONFIG_SRC" ]; then
  cp "$CONFIG_SRC" .config
else
  # arm64 用 defconfig；x86 用 x86_64_defconfig
  case "$(uname -m)" in
    aarch64|arm64) make defconfig ;;
    *)             make x86_64_defconfig ;;
  esac
  # 去掉 Debian 专属的证书要求，避免 "No rule to make target debian/certs" 
  ./scripts/config --disable MODULE_SIG_ALL --disable SYSTEM_TRUSTED_KEYS \
                   --disable SYSTEM_REVOCATION_KEYS || true
fi
./scripts/config \
  --set-str LOCALVERSION "$LOCALVERSION" \
  --set-str DEFAULT_HOSTNAME "$BRAND" \
  --enable IKCONFIG --enable IKCONFIG_PROC \
  --set-str CMDLINE "console=tty1 root=PARTUUID=%U/PARTNROFF=1 rootwait rw quiet" \
  || true
make olddefconfig

# ------------------------------------------------------------ 编译 ----
log "开始编译（-j$JOBS，约 40-90 分钟）"
make -j"$JOBS" Image modules dtbs
log "打包 .deb"
make -j"$JOBS" KBUILD_BUILD_USER=wanglinux KBUILD_BUILD_HOST="$BRAND" \
     bindeb-pkg LOCALVERSION="$LOCALVERSION"

ls -lh "$BUILDROOT"/*.deb 2>/dev/null || ls -lh ../*.deb

cat <<EOF

======== 构建完成 ========
内核版本 : $SRCVER$LOCALVERSION
产物     : $BUILDROOT/../linux-image-${SRCVER}${LOCALVERSION}_*.deb
           $BUILDROOT/../linux-headers-${SRCVER}${LOCALVERSION}_*.deb
下一步   :
  1) 把 .deb 放进 aurora 仓库的 pool/main/l/linux-image-${BRAND}/
  2) bash build-repo.sh 重建索引
  3) apt install linux-image-${SRCVER}${LOCALVERSION}
  4) update-initramfs -c -k ${SRCVER}${LOCALVERSION}
  5) 目标是"离开宿主内核能独立启动"：还需在目标机装 bootloader（GRUB/EXT4 或
     树莓派固件 config.txt + kernel8.img），这一步必须实机验证。
EOF

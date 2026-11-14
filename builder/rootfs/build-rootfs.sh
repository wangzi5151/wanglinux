#!/bin/bash
# ============================================================================
#  WangLinux 通用 rootfs tarball
#  支持架构：amd64 / arm64 / armhf / riscv64（默认取本机架构）
#  产出：wanglinux-rootfs-<arch>-<版本>.tar.gz + .sha256
#  用途：chroot、systemd-nspawn、容器底座、任何平台的定制起点
#  用法：ARCH=arm64 bash build-rootfs.sh
# ============================================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$HERE/../lib/common.sh"

ARCH="${ARCH:-$(dpkg --print-architecture)}"
OUT="${OUT:-$HERE/out}"
NAME="wanglinux-rootfs-${ARCH}-${WL_VERSION}.tar.gz"

need_root
mkdir -p "$OUT"
ROOTFS="$OUT/rootfs-build"
rm -rf "$ROOTFS"
trap 'rm -rf "$ROOTFS"' EXIT

wl_bootstrap "$ARCH" "$ROOTFS" systemd systemd-sysv dbus
wl_add_repo "$ROOTFS"
wl_install "$ROOTFS" wanglinux-base wanglinux-tools
wl_setup_base "$ROOTFS"
wl_cleanup "$ROOTFS"

log "打包 $NAME"
cd "$ROOTFS" && tar --numeric-owner -czf "$OUT/$NAME" .
cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256"

cat <<MSG

====== rootfs 完成 ======
  $OUT/$NAME
  使用（systemd-nspawn 示例）：
    mkdir -p /srv/wanglinux && tar -xzf $NAME -C /srv/wanglinux
    systemd-nspawn -D /srv/wanglinux -b
  登录：$WL_USER / $WL_PASS （root 同密码，首次登录请修改）
MSG

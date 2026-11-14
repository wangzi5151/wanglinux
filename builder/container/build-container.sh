#!/bin/bash
# ============================================================================
#  WangLinux OCI 容器镜像（docker / podman 可直接 import）
#  支持架构：amd64 / arm64
#  产出：wanglinux-oci-<arch>-<版本>.tar
#  用法：ARCH=arm64 bash build-container.sh
#        之后：docker import wanglinux-oci-arm64-1.0.tar wanglinux:1.0
# ============================================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$HERE/../lib/common.sh"

ARCH="${ARCH:-amd64}"
FLAVOR="${FLAVOR:-minimal}"     # minimal = base+tools；server = base+tools+server
OUT="${OUT:-$HERE/out}"
NAME="wanglinux-oci-${ARCH}-${WL_VERSION}.tar"

need_root
mkdir -p "$OUT"
ROOTFS="$OUT/container-rootfs"
rm -rf "$ROOTFS"
trap 'rm -rf "$ROOTFS"' EXIT

# 容器不需要 systemd init（用宿主编排器），保持精炼
wl_bootstrap "$ARCH" "$ROOTFS"
wl_add_repo "$ROOTFS"
case "$FLAVOR" in
  server) wl_install "$ROOTFS" wanglinux-base wanglinux-tools wanglinux-server ;;
  *)      wl_install "$ROOTFS" wanglinux-base wanglinux-tools ;;
esac
wl_setup_base "$ROOTFS"
wl_cleanup "$ROOTFS"

# 容器镜像要求根目录是 tar 平铺格式，且不含 host 侧路径信息
log "打包 OCI 镜像 $NAME"
cd "$ROOTFS" && tar --numeric-owner -cf "$OUT/$NAME" .
cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256"

cat <<MSG

====== 容器镜像完成 ======
  $OUT/$NAME
  导入：
    docker import $NAME wanglinux:$WL_VERSION
    docker run -it wanglinux:$WL_VERSION /bin/bash
  （server 变体：FLAVOR=server bash build-container.sh）
MSG

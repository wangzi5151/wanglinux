#!/bin/bash
# ============================================================================
#  WangLinux WSL 导入包（Windows Subsystem for Linux）
#  仅支持 amd64（WSL 目前主要在 x86_64 上运行）
#  产出：wanglinux-wsl-1.0.tar.gz
#  用法：bash build-wsl.sh
#        之后（Windows PowerShell）：
#          wsl --import WangLinux C:\WangLinux wanglinux-wsl-1.0.tar.gz
#          wsl -d WangLinux
# ============================================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$HERE/../lib/common.sh"

OUT="${OUT:-$HERE/out}"
NAME="wanglinux-wsl-${WL_VERSION}.tar.gz"

need_root
mkdir -p "$OUT"
ROOTFS="$OUT/wsl-rootfs"
rm -rf "$ROOTFS"
trap 'rm -rf "$ROOTFS"' EXIT

wl_bootstrap amd64 "$ROOTFS" systemd dbus sudo
wl_add_repo "$ROOTFS"
wl_install "$ROOTFS" wanglinux-base wanglinux-tools wanglinux-server
wl_setup_base "$ROOTFS"

# WSL 配置：默认用户 + 宿主机文件系统互通
cat > "$ROOTFS/etc/wsl.conf" <<WSL
[user]
default=$WL_USER

[automount]
enabled=true
root=/mnt/

[network]
generateHosts=true
generateResolvConf=true

[boot]
systemd=true
WSL

wl_cleanup "$ROOTFS"

log "打包 WSL 镜像 $NAME"
cd "$ROOTFS" && tar --numeric-owner -czf "$OUT/$NAME" .
cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256"

cat <<MSG

====== WSL 包完成 ======
  $OUT/$NAME
  导入（Windows）：
    wsl --import WangLinux C:\\WangLinux .\\$NAME
    wsl -d WangLinux
  登录：$WL_USER / $WL_PASS（root 同密码）
MSG

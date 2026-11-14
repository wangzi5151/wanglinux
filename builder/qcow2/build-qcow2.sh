#!/bin/bash
# ============================================================================
#  WangLinux 云镜像（qcow2，含 cloud-init）
#  支持架构：amd64 / arm64
#  产出：wanglinux-cloud-<arch>-<版本>.qcow2
#  说明：本脚本沿用 WangLinux「无 loop 设备」哲学——直接用 mke2fs -d 填充根
#        文件系统，再交给 qemu-img 转成 qcow2。云上/虚拟化里用「直接内核引导」
#        （QEMU -kernel / cloud-init）或作为云镜像种子；完整的 BIOS/EFI 引导
#        装机请走 builder/iso 与 builder/arm64。
#  用法：ARCH=arm64 bash build-qcow2.sh
# ============================================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$HERE/../lib/common.sh"

ARCH="${ARCH:-amd64}"
SIZE="${SIZE:-4G}"
OUT="${OUT:-$HERE/out}"
NAME="wanglinux-cloud-${ARCH}-${WL_VERSION}.qcow2"

need_root
mkdir -p "$OUT"
ROOTFS="$OUT/cloud-rootfs"
RAW="$OUT/cloud-$$.raw"
rm -rf "$ROOTFS" "$RAW"
trap 'rm -rf "$ROOTFS" "$RAW"' EXIT

wl_bootstrap "$ARCH" "$ROOTFS" systemd systemd-sysv cloud-init openssh-server
wl_add_repo "$ROOTFS"
wl_install "$ROOTFS" wanglinux-base wanglinux-tools wanglinux-server
wl_setup_base "$ROOTFS"

# cloud-init 需要禁用默认密码登录提示（由 cloud-init 注入用户/密钥）
rm -f "$ROOTFS/etc/cloud/cloud.cfg.d/99-wanglinux.cfg"
cat > "$ROOTFS/etc/cloud/cloud.cfg.d/99-wanglinux.cfg" <<CFG
datasource_list: [ NoCloud, None ]
disable_root: false
ssh_pwauth: true
CFG
echo 'wanglinux' > "$ROOTFS/etc/cloud/cloud.cfg.d/99-hostname.cfg"

wl_cleanup "$ROOTFS"

log "创建 ext4 根并填充（$SIZE，无 loop）"
truncate -s "$SIZE" "$RAW"
mke2fs -t ext4 -F -L WANGLINUX -m 1 -d "$ROOTFS" "$RAW" >/dev/null

log "转成 qcow2 → $NAME"
qemu-img convert -f raw -O qcow2 "$RAW" "$OUT/$NAME"
cd "$OUT" && sha256sum "$NAME" > "$NAME.sha256"

cat <<MSG

====== 云镜像完成 ======
  $OUT/$NAME
  直接内核引导（QEMU）：
    qemu-system-x86_64 -m 2048 -drive file=$NAME,format=qcow2 \\
      -kernel vmlinuz -initrd initrd.img -append "root=/dev/sda ro console=ttyS0"
  登录：cloud-init 注入，或 $WL_USER / $WL_PASS（ssh_pwauth=true，首次登录请改密）
MSG

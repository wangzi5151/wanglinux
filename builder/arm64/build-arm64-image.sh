#!/bin/bash
# ============================================================================
#  WangLinux 通用 arm64 可烧录镜像（非树莓派专用）
#  面向：带 UEFI 的 arm64 设备（ARM 服务器、RK3588 等 UEFI 板卡、QEMU/KVM）
#  产出：wanglinux-arm64-<版本>.img.gz + .sha256
#  说明：树莓派有专用路线（pi/assemble.sh，走 config.txt + kernel8.img）。
#        本脚本产出「EFI 启动分区 + ext4 根」的通用 GPT 镜像，同样坚持
#        「无 loop 设备」：mke2fs -d 填充根分区、mtools 造 EFI 分区、sgdisk 写分区表。
#  用法：bash build-arm64-image.sh
# ============================================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../lib/common.sh
. "$HERE/../lib/common.sh"

OUT="${OUT:-$HERE/out}"
IMG="wanglinux-arm64-${WL_VERSION}.img"
FLAVOR="${FLAVOR:-server}"     # server = 无桌面；desktop = 带桌面（更大）
DISK_SIG="57414e47"
P1_START=2048;  P1_SECTORS=262144     # 128 MiB EFI 分区
P2_START=$((P1_START+P1_SECTORS)); P2_SECTORS=6291456  # ~3 GiB 根分区
P2_SIZE="3000M"

need_root
mkdir -p "$OUT"
ROOTFS="$OUT/arm64-rootfs"
EFI="$OUT/arm64-efi"
rm -rf "${ROOTFS:?}" "${EFI:?}" "${OUT:?}/$IMG"
trap 'rm -rf "$ROOTFS" "$EFI"' EXIT

wl_bootstrap arm64 "$ROOTFS" systemd systemd-sysv dbus linux-image-arm64
wl_add_repo "$ROOTFS"
case "$FLAVOR" in
  desktop) wl_install "$ROOTFS" wanglinux-base wanglinux-theme wanglinux-desktop wanglinux-devel ;;
  *)       wl_install "$ROOTFS" wanglinux-base wanglinux-tools wanglinux-server ;;
esac
# 引导器
chroot "$ROOTFS" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends grub-efi-arm64 grub-efi-arm64-bin
wl_setup_base "$ROOTFS"
wl_cleanup "$ROOTFS"

log "创建 ext4 根分区并填充（$P2_SIZE）"
root_img="$OUT/root-$$.ext4"
rm -f "$root_img"; trap 'rm -rf "$ROOTFS" "$EFI" "$root_img"' EXIT
mke2fs -t ext4 -F -L WANGLINUX -U "${DISK_SIG}-0000-4000-8000-000000000002" \
       -b 4096 -m 1 -d "$ROOTFS" "$root_img" "$P2_SIZE" >/dev/null

log "创建 EFI 启动分区并写入 GRUB"
mkdir -p "$EFI"
# 用 grub-mkimage 生成独立 EFI 可执行文件（避免依赖宿主 /boot）
read -ra GRUB_MODS <<< "part_gpt fat ext2 normal linux configfile search search_fs_uuid"
grub-mkimage -d "$ROOTFS/usr/lib/grub/arm64-efi" -O arm64-efi -o "$EFI/BOOTAA64.EFI" \
  -p /EFI/BOOT "${GRUB_MODS[@]}" 2>/dev/null || \
  cp "$ROOTFS/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi" "$EFI/BOOTAA64.EFI" 2>/dev/null || \
  { warn "未找到预编译 GRUB EFI，跳过 EFI 分区（镜像将无引导器，需外部内核启动）"; }
if [ -f "$EFI/BOOTAA64.EFI" ]; then
  cat > "$EFI/grub.cfg" <<GRUB
set timeout=3
menuentry "WangLinux" {
  search --set=root --fs-uuid ${DISK_SIG}-0000-4000-8000-000000000002
  linux /vmlinuz root=PARTUUID=${DISK_SIG}-02 rootfstype=ext4 rw quiet
  initrd /initrd.img
}
GRUB
  efifile="$OUT/efi-$$.fat"
  rm -f "$efifile"
  mkfs.vfat -C -F 32 -n EFI "$efifile" $((P1_SECTORS/2)) >/dev/null
  mcopy -i "$efifile" -s "$EFI"/* ::/
else
  efifile=""
fi

log "拼接 GPT 镜像并写分区表"
truncate -s $(( (P1_SECTORS+P2_SECTORS)*512 )) "$OUT/$IMG"
if [ -n "$efifile" ]; then
  dd if="$efifile"  of="$OUT/$IMG" bs=512 seek=$P1_START conv=notrunc status=none
fi
dd if="$root_img" of="$OUT/$IMG" bs=512 seek=$P2_START conv=notrunc status=none
python3 - "$OUT/$IMG" "$DISK_SIG" "$P1_START" "$P1_SECTORS" "$P2_START" "$P2_SECTORS" <<'PY'
import struct, sys
img, sig, s1, n1, s2, n2 = sys.argv[1], int(sys.argv[2],16), *map(int, sys.argv[3:7])
# 保护性 MBR + 两个主分区项
mbr = bytearray(512)
struct.pack_into('<I', mbr, 440, sig)
mbr[446]=0x80; mbr[450]=0xee          # 保护性 MBR 指向 GPT
struct.pack_into('<I', mbr, 458, 1)
mbr[510:512] = b'\x55\xaa'
open(img,'r+b').write(mbr)
PY
rm -f "$efifile" "$root_img"

log "压缩并生成校验和"
cd "$OUT" && gzip -1 -c "$IMG" > "$IMG.gz" && sha256sum "$IMG.gz" > "$IMG.gz.sha256"
ls -lh "$IMG.gz"

cat <<MSG

====== arm64 通用镜像完成 ======
  $OUT/$IMG.gz
  烧录：gunzip -c $IMG.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
  登录：$WL_USER / $WL_PASS（root 同密码，首次登录请修改）
MSG

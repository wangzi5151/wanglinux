#!/bin/bash
# ============================================================================
#  WangLinux 1.0 (Aurora) — Raspberry Pi arm64 镜像组装脚本
#  在没有 loop 设备的环境（PRoot / 手机 chroot）里也能跑：
#  用 mke2fs -d 直接填充 ext4、mkfs.vfat 造 FAT、python 手写 MBR。
#
#  用法（root）：
#    SRC=/opt/wl-pi  bash assemble.sh
#  依赖：mke2fs/resize2fs/tune2fs/dumpe2fs/debugfs、dosfstools(mkfs.vfat)、
#        mtools(mcopy/mdir)、sfdisk、python3
# ============================================================================
set -Eeuo pipefail

SRC="${SRC:-/opt/wl-pi}"              # 已配置好的 arm64 rootfs
OUT="${OUT:-/workspace/wl-build}"     # 工作目录
KERNEL_VER="${KERNEL_VER:-6.1.0-50-arm64}"
DISK_SIG="57414e47"                   # MBR disk signature → PARTUUID 前缀
P1_START=8192;  P1_SECTORS=524288     # 4MiB 起，256MiB FAT32 /boot/firmware
P2_START=532480; P2_SECTORS=6963200   # 260MiB 起，3.3GiB ext4 /
P2_SIZE="3400M"

log() { printf '\n\033[1;35m[pi]\033[0m %s\n' "$*"; }
[ "$(id -u)" -eq 0 ] || { echo "需要 root"; exit 1; }
mkdir -p "$OUT"; cd "$OUT"

# ---------------------------------------------------------------- 1. rootfs ----
log "拷贝并清理 rootfs（跳过虚拟目录与 apt 缓存）"
rm -rf rootfs; mkdir -p rootfs
cp -a "$SRC"/. rootfs/
rm -rf rootfs/proc/* rootfs/sys/* rootfs/dev/* rootfs/run/* rootfs/tmp/* \
       rootfs/var/lib/apt/lists/* rootfs/var/cache/apt/archives/*.deb
mkdir -p rootfs/proc rootfs/sys rootfs/dev rootfs/run rootfs/tmp rootfs/boot/firmware
chmod 1777 rootfs/tmp
# PRoot 会把 rename 变成 .l2s.* 临时文件，必须还原成真名，否则镜像里是断链
python3 - <<'PY'
import os, shutil
S='rootfs'
for d,keys in (('var/lib/dpkg',('status','diversions','statoverride')),):
    for f in os.listdir(os.path.join(S,d)):
        if f.startswith('.l2s.'):
            for k in keys:
                if f[5:].startswith(k):
                    t=os.path.join(S,d,k)
                    if os.path.isfile(os.path.join(S,d,f)):
                        if not (os.path.exists(t) and os.path.getsize(t)>0):
                            shutil.copy2(os.path.join(S,d,f), t)
                        os.remove(os.path.join(S,d,f))
                    break
PY

# ------------------------------------------------------------------ 2. boot ----
log "组装启动分区内容"
B="$OUT/boot"; mkdir -p "$B"
cp "$SRC/boot/vmlinuz-$KERNEL_VER"      "$B/kernel8.img"   # arm64 Image（未压缩）
cp "$SRC/boot/initrd.img-$KERNEL_VER"   "$B/initrd.img"
for f in start4.elf fixup4.dat start.elf fixup.dat bootcode.bin; do
  [ -f "$SRC/usr/lib/raspi-firmware/$f" ] && cp "$SRC/usr/lib/raspi-firmware/$f" "$B/"
done
for d in bcm2711-rpi-4-b bcm2711-rpi-400 bcm2711-rpi-cm4-io bcm2837-rpi-3-b-plus; do
  cp "$SRC/usr/lib/linux-image-$KERNEL_VER/broadcom/$d.dtb" "$B/" 2>/dev/null || true
done
cat > "$B/config.txt" <<'CFG'
arm_64bit=1
kernel=kernel8.img
initramfs initrd.img followkernel
disable_overscan=1
enable_uart=1
gpu_mem=128
dtparam=audio=on
hdmi_force_hotplug=1
boot_delay=0

[pi4]
device_tree=bcm2711-rpi-4-b.dtb
[pi400]
device_tree=bcm2711-rpi-400.dtb
[cm4]
device_tree=bcm2711-rpi-cm4-io.dtb
[pi3]
device_tree=bcm2837-rpi-3-b-plus.dtb
CFG
cat > "$B/cmdline.txt" <<CMD
console=serial0,115200 console=tty1 root=PARTUUID=${DISK_SIG}-02 rootfstype=ext4 rootwait fsck.repair=yes quiet logo.nologo
CMD

# ------------------------------------------------------------- 3. ext4 根 ----
log "创建 ext4 根分区并用目录内容填充（无 loop）"
rm -f rootfs.ext4
mke2fs -t ext4 -F -L WANGLINUX -U "${DISK_SIG}-0000-4000-8000-000000000002" \
       -b 4096 -m 1 -O ^has_journal -d rootfs rootfs.ext4 "$P2_SIZE"
tune2fs -j rootfs.ext4 >/dev/null          # 补日志，保证 SD 卡断电安全
dumpe2fs -h rootfs.ext4 2>/dev/null | grep -E "Filesystem volume name|Block count|Journal inode"

# -------------------------------------------------------------- 4. FAT32 ----
log "创建 FAT32 启动分区并拷入文件"
rm -f boot.fat
mkfs.vfat -C -F 32 -n BOOT boot.fat $((P1_SECTORS/2)) >/dev/null
mcopy -i boot.fat -s -Q "$B"/* ::/
mdir -i boot.fat ::/ | tail -3

# ------------------------------------------------------- 5. 拼镜像 + MBR ----
log "拼接镜像并写入 MBR（disk signature ${DISK_SIG}）"
IMG="wanglinux-pi-1.0.img"
rm -f "$IMG"
truncate -s $(( 4+256+3400 ))M "$IMG"
dd if=boot.fat     of="$IMG" bs=1M seek=4   conv=notrunc status=none
dd if=rootfs.ext4  of="$IMG" bs=1M seek=260 conv=notrunc status=none
python3 - "$IMG" "$DISK_SIG" "$P1_START" "$P1_SECTORS" "$P2_START" "$P2_SECTORS" <<'PY'
import struct, sys
img, sig, s1, n1, s2, n2 = sys.argv[1], int(sys.argv[2],16), *map(int, sys.argv[3:7])
mbr = bytearray(512)
struct.pack_into('<I', mbr, 440, sig)
for i,(typ,start,size,flag) in enumerate(((0x0c,s1,n1,0x80),(0x83,s2,n2,0x00)), 1):
    o = 446 + (i-1)*16
    mbr[o] = flag; mbr[o+4] = typ
    struct.pack_into('<I', mbr, o+8, start)
    struct.pack_into('<I', mbr, o+12, size)
mbr[510:512] = b'\x55\xaa'
open(img,'r+b').write(mbr)
PY
sfdisk -l "$IMG" | tail -4

# ------------------------------------------------------------ 6. 收尾 ----
log "压缩并生成校验和"
gzip -1 -c "$IMG" > "$IMG.gz"
sha256sum "$IMG.gz" > "$IMG.gz.sha256"
ls -lh "$IMG" "$IMG.gz"; cat "$IMG.gz.sha256"

cat <<EOF

完成。烧录：
  gunzip -c $IMG.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
首次登录：wang / wanglinux（root 同密码），SSH 已开，首次开机自动扩容根分区。
EOF

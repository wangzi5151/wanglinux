#!/bin/bash
# ============================================================================
#  WangLinux 1.0 (amd64) 可启动 U 盘 ISO 构建脚本
#  在 Debian 12 / Ubuntu 22.04+ / WSL2-Ubuntu 上以 root 运行
#  产出：wanglinux-1.0-amd64.iso（UEFI + 传统 BIOS 双启动，可 Rufus 写盘）
# ============================================================================
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

DIST="${DIST:-bookworm}"
MIRROR="${MIRROR:-http://mirrors.ustc.edu.cn/debian/}"
MIRROR_SEC="${MIRROR_SEC:-http://mirrors.ustc.edu.cn/debian-security/}"
WORK="${WORK:-/build/wanglinux-iso}"
OUT="${OUT:-/build}"
ISONAME="wanglinux-1.0-amd64.iso"
VERSION="1.0"

log()  { printf '\n\033[1;35m[WangLinux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[注意]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[失败]\033[0m %s\n' "$*" >&2; exit 1; }
trap 'die "构建中断（第 $LINENO 行）。日志：$WORK/build.log"' ERR

[ "$(id -u)" -eq 0 ] || die "请用 root 运行： sudo bash $0"

# ---------------------------------------------------------------- 1. 依赖 ----
log "1/7 安装构建依赖（首次约 100 MB）"
apt-get update -qq
apt-get install -y --no-install-recommends \
  live-build debootstrap squashfs-tools xorriso isolinux syslinux-common syslinux-efi \
  grub-pc-bin grub-efi-amd64-bin mtools dosfstools rsync ca-certificates xz-utils \
  >/tmp/wanglinux-deps.log 2>&1 || die "依赖安装失败，见 /tmp/wanglinux-deps.log"

# ---------------------------------------------------------------- 2. 骨架 ----
log "2/7 初始化构建目录 $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"/config/{package-lists,hooks/live,includes.chroot/usr/local/bin,includes.chroot/etc}
cd "$WORK"

lb config noauto \
  --architectures amd64 \
  --distribution "$DIST" \
  --mode debian \
  --system live \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free-firmware" \
  --parent-archive-areas "main contrib non-free-firmware" \
  --debian-installer none \
  --memtest none \
  --checksums sha256 \
  --bootappend-live "boot=live components persistence username=wang user-fullname=Wang hostname=wanglinux locales=zh_CN.UTF-8 keyboard-layouts=us timezone=Asia/Shanghai utc=no quiet splash" \
  --iso-application "WangLinux ${VERSION}" \
  --iso-preparer "WangLinux Project" \
  --iso-publisher "WangLinux Project; https://example.com/wanglinux" \
  --iso-volume "WANGLINUX_10" \
  --mirror-bootstrap "$MIRROR" \
  --mirror-chroot "$MIRROR" \
  --mirror-binary "$MIRROR" \
  --mirror-chroot-security "$MIRROR_SEC" \
  --mirror-binary-security "$MIRROR_SEC"

# ------------------------------------------------------- 3. 软件包清单 ----
log "3/7 写入软件包清单"
cat > config/package-lists/wanglinux-core.list.chroot <<'EOF'
# ---- 桌面环境 ----
task-xfce-desktop
lightdm
lightdm-gtk-greeter
xfce4-terminal
thunar
mousepad
xfce4-pulseaudio-plugin
pavucontrol
network-manager
network-manager-gnome
firefox-esr
# ---- 中文支持 ----
locales
fonts-noto-cjk
fonts-noto-color-emoji
fonts-wqy-zenhei
fcitx5
fcitx5-chinese-addons
fcitx5-frontend-gtk3
# ---- 与 arm64 版一致的基础工具 ----
bash-completion
curl
wget
git
vim
nano
less
tree
htop
procps
psmisc
file
unzip
zip
xz-utils
bzip2
sudo
tzdata
net-tools
iproute2
iputils-ping
dnsutils
openssh-client
openssh-server
python3
python3-pip
python3-venv
perl
gcc
g++
make
cmake
gdb
strace
tmux
rsync
jq
ncdu
man-db
manpages
cron
ca-certificates
gnupg
lsb-release
usbutils
pciutils
lsof
socat
bc
zsh
neofetch
EOF

# --------------------------------------------------------- 4. 品牌文件 ----
log "4/7 写入品牌文件与自研命令"
cat > config/includes.chroot/usr/local/bin/wanginfo <<'EOF'
#!/bin/sh
REL=$(sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release 2>/dev/null)
[ -n "$REL" ] || REL="WangLinux 1.0 (Aurora)"
SH="${SHELL:-$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f7)}"; [ -n "$SH" ] || SH=/bin/bash
PKGS=$(dpkg-query -f '.\n' -W 2>/dev/null | wc -l)
KERN=$(uname -r 2>/dev/null); KNOTE=""
case "$KERN" in *android*) KNOTE=" [宿主内核]";; "") KERN="未知";; esac
printf '%-9s %s\n' "系统"   "$REL"
printf '%-9s %s\n' "基础"   "Debian $(cat /etc/debian_version 2>/dev/null) (bookworm) / $(uname -m)"
printf '%-9s %s\n' "内核"   "$KERN$KNOTE"
printf '%-9s %s\n' "软件包" "$PKGS 个"
printf '%-9s %s\n' "CPU"    "$(uname -m) x $(nproc 2>/dev/null || echo 1)"
printf '%-9s %s\n' "内存"   "$(awk '/MemTotal/{printf "%.1f GiB", $2/1048576}' /proc/meminfo 2>/dev/null)"
printf '%-9s %s\n' "用户"   "$(id -un) (uid=$(id -u))"
printf '%-9s %s\n' "Shell"  "$SH"
printf '%-9s %s\n' "开机"   "$(uptime -p 2>/dev/null || echo '—')"
EOF
chmod +x config/includes.chroot/usr/local/bin/wanginfo

cat > config/includes.chroot/usr/local/bin/help-wang <<'EOF'
#!/bin/sh
printf '%s\n' \
"WangLinux 快速指引" \
"  wanginfo                 系统信息" \
"  apt update && apt install 装软件（源已指向 USTC 镜像）" \
"  sudo 前缀                以管理员身份执行" \
"  浏览器 / 文件管理器 / 终端  左下角菜单里都有" \
"  中文输入法                Ctrl+空格 切换（fcitx5）" \
"  重启 / 关机               右上角菜单"
EOF
chmod +x config/includes.chroot/usr/local/bin/help-wang

cat > config/includes.chroot/etc/lightdm/lightdm.conf <<'EOF'
[Seat:*]
autologin-user=wang
autologin-user-timeout=0
greeter-session=lightdm-gtk-greeter
user-session=xfce
EOF

# ------------------------------------------------------- 5. 构建时钩子 ----
log "5/7 写入构建钩子（品牌化 / 中文 / 壁纸 / 密码）"
cat > config/hooks/live/0100-branding.hook.chroot <<'HOOK'
#!/bin/sh
set -e
# --- os-release（真正替换 Debian 标识）---
cat > /usr/lib/os-release <<'EOF'
PRETTY_NAME="WangLinux 1.0"
NAME="WangLinux"
VERSION_ID="1.0"
VERSION="1.0 (Aurora)"
VERSION_CODENAME=aurora
ID=wanglinux
ID_LIKE=debian
ANSI_COLOR="1;35"
HOME_URL="https://example.com/wanglinux"
SUPPORT_URL="https://example.com/wanglinux/support"
BUG_REPORT_URL="https://example.com/wanglinux/issues"
EOF
rm -f /etc/os-release && ln -s ../usr/lib/os-release /etc/os-release
cat > /etc/lsb-release <<'EOF'
DISTRIB_ID=WangLinux
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=aurora
DISTRIB_DESCRIPTION="WangLinux 1.0"
EOF
echo "WangLinux 1.0 (Aurora) - Debian bookworm base / amd64" > /etc/wanglinux-release
echo wanglinux > /etc/hostname
printf '127.0.0.1\tlocalhost\n127.0.1.1\twanglinux\n' > /etc/hosts
printf 'WangLinux 1.0 \\n \\l\n\n' > /etc/issue
printf 'WangLinux 1.0 \\n \\l\n\n' > /etc/issue.net
cat > /etc/motd <<'EOF'

   WangLinux 1.0 (Aurora)  ·  amd64

   开机即用：浏览器 / 文件管理器 / 终端都在左下角菜单
   输入 help-wang 看常用操作，输入 wanginfo 看系统信息
   中文输入法：Ctrl+空格

EOF
# --- 引导菜单显示的名字 ---
if [ -f /etc/default/grub ]; then
  sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="WangLinux"/' /etc/default/grub || \
    echo 'GRUB_DISTRIBUTOR="WangLinux"' >> /etc/default/grub
fi
# --- 时区 / 中文 locale ---
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone
sed -i 's/^# *\(zh_CN.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen 2>/dev/null || true
echo 'LANG=zh_CN.UTF-8' > /etc/default/locale
echo 'LANGUAGE=zh_CN:en_US' >> /etc/default/locale
locale-gen || true
# --- 用户密码 & 免密 sudo ---
echo 'wang:wanglinux' | chpasswd || true
echo 'root:wanglinux' | chpasswd || true
mkdir -p /etc/sudoers.d
echo 'wang ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/010-wang
chmod 440 /etc/sudoers.d/010-wang
# --- fcitx5 自启 ---
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/wang-fcitx5.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Input Method (fcitx5)
Exec=fcitx5 -d
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF
# --- 壁纸：无外部依赖，用 python3 现画一张渐变图 ---
mkdir -p /usr/share/backgrounds
python3 - <<'PY' || true
import zlib, struct
W, H = 1920, 1080
raw = bytearray()
for y in range(H):
    t = y / H
    r = int(24 + 90 * t)
    g = int(8 + 24 * (1 - t))
    b = int(48 + 170 * t)
    raw.append(0)
    raw += bytes((r, g, b)) * W
def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(bytes(raw), 6))
       + chunk(b'IEND', b''))
open('/usr/share/backgrounds/wanglinux.png', 'wb').write(png)
PY
cat > /etc/xdg/autostart/wang-wallpaper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=WangLinux Wallpaper
Exec=sh -c 'for p in $(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep last-image); do xfconf-query -c xfce4-desktop -p "$p" -s /usr/share/backgrounds/wanglinux.png 2>/dev/null; done'
OnlyShowIn=XFCE;
EOF
exit 0
HOOK
chmod +x config/hooks/live/0100-branding.hook.chroot

cat > config/hooks/live/0200-extras.hook.chroot <<'HOOK'
#!/bin/sh
# 可选增强包：某个名字在当前源不可用时只跳过，不中断构建
apt-get update -qq || true
for p in fcitx5-frontend-qt5 fcitx5-config-qt fcitx5-table-extra \
         xscreensaver xfce4-screenshooter xfce4-taskmanager \
         gvfs-backends udisks2 exfat-fuse ntfs-3g \
         imagemagick htop neofetch cowsay sl figlet; do
  apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 || echo "跳过可选包: $p"
done
apt-get -y autoremove --purge >/dev/null 2>&1 || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 2>/dev/null || true
exit 0
HOOK
chmod +x config/hooks/live/0200-extras.hook.chroot

# ---------------------------------------------------------------- 6. 构建 ----
log "6/7 开始构建（下载约 1.5-2.5 GB，40-90 分钟，可离开）"
lb build 2>&1 | tee "$WORK/build.log" | grep -E "^(P:|I:|E:|\[)" --line-buffered || true
[ -f live-image-amd64.hybrid.iso ] || die "没有生成 ISO，看日志：$WORK/build.log"

# ---------------------------------------------------------------- 7. 收尾 ----
log "7/7 校验并输出"
mkdir -p "$OUT"
mv -f live-image-amd64.hybrid.iso "$OUT/$ISONAME"
cd "$OUT" && sha256sum "$ISONAME" | tee "$ISONAME.sha256"
SIZE=$(du -h "$ISONAME" | cut -f1)
cat <<EOF

====== 构建完成 ======
  ISO    : $OUT/$ISONAME  ($SIZE)
  校验值 : $(cut -d' ' -f1 "$ISONAME.sha256")
  启动   : UEFI 与传统 BIOS 双支持
  账号   : wang / wanglinux   root / wanglinux
  下一步 : Rufus 选「GPT + UEFI」写入 U 盘 → 开机按 F12/F8/Esc 选 U 盘
  持久化 : 见 README 的「持久化」一节
EOF

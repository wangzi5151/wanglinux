#!/bin/bash
# ============================================================================
#  build-iso.sh —— 真实构建 WangLinux 1.0 amd64 桌面 ISO（live-build）
#  产出：wanglinux-1.0-amd64.iso（UEFI + BIOS 双启动，可 Rufus 写盘）
#  用法：sudo bash build-iso.sh <仓库路径> <公钥路径>
# ============================================================================
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
REPO="${1:-/opt/wanglinux-repo}"
KEYRING="${2:-}"
WORK="${WORK:-/root/.codebuddy/artifact/2f8a7d30-9c21-4f0b-1d68-1b19200c9000/build/iso-build}"
OUT="${OUT:-/root/.codebuddy/artifact/2f8a7d30-9c21-4f0b-1d68-1b19200c9000/build/out}"
MIRROR="https://mirrors.ustc.edu.cn/debian"
ISONAME="wanglinux-1.0-amd64.iso"

log() { printf '\n\033[1;35m[iso]\033[0m %s\n' "$*"; }
[ "$(id -u)" -eq 0 ] || { echo "需要 root"; exit 1; }

log "1/5 初始化构建目录"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
lb config noauto \
  --architectures amd64 \
  --distribution bookworm \
  --mode debian \
  --system live \
  --binary-images iso-hybrid \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer none \
  --memtest none \
  --checksums sha256 \
  --linux-packages "linux-image" \
  --linux-flavours "amd64" \
  --firmware-chroot false \
  --firmware-binary false \
  --security false \
  --bootappend-live "boot=live components quiet splash username=wang user-fullname=Wang hostname=wanglinux locales=zh_CN.UTF-8 keyboard-layouts=us timezone=Asia/Shanghai utc=no" \
  --iso-application "WangLinux 1.0 (Aurora)" \
  --iso-preparer "WangLinux Project" \
  --iso-publisher "WangLinux Project; https://github.com/wangzi5151/wanglinux" \
  --iso-volume "WANGLINUX_10" \
  --mirror-bootstrap "$MIRROR" \
  --mirror-chroot "$MIRROR" \
  --mirror-binary "$MIRROR"

log "2/5 写入软件包清单（Xfce 桌面 + 中文 + 浏览器 + 常用工具）"
cat > config/package-lists/wanglinux-desktop.list.chroot <<'EOF'
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
locales
fonts-noto-cjk
fonts-noto-color-emoji
fonts-wqy-zenhei
fcitx5
fcitx5-chinese-addons
fcitx5-frontend-gtk3
fcitx5-config-qt
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
rsync
jq
ncdu
man-db
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

log "3/5 写入品牌化钩子（os-release / motd / 壁纸 / 用户 / 中文）"
mkdir -p config/hooks/live config/includes.chroot
cat > config/hooks/live/0100-branding.hook.chroot <<'HOOK'
#!/bin/sh
set -e
cat > /etc/os-release <<'EOF'
PRETTY_NAME="WangLinux 1.0 (Aurora)"
NAME="WangLinux"
VERSION_ID="1.0"
VERSION="1.0 (Aurora)"
VERSION_CODENAME=aurora
ID=wanglinux
ID_LIKE=debian
ANSI_COLOR="1;35"
HOME_URL="https://github.com/wangzi5151/wanglinux"
EOF
cat > /etc/lsb-release <<'EOF'
DISTRIB_ID=WangLinux
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=aurora
DISTRIB_DESCRIPTION="WangLinux 1.0 (Aurora)"
EOF
echo "WangLinux 1.0 (Aurora) - Debian bookworm / amd64" > /etc/wanglinux-release
echo wanglinux > /etc/hostname
printf '127.0.0.1\tlocalhost\n127.0.1.1\twanglinux\n' > /etc/hosts
cat > /etc/motd <<'EOF'

   __      ___                  _     _ _
   \ \    / /_ _ _ __   __ _   | |   (_)_ __  _   ___  __
    \ \/\/ / _` | '_ \ / _` |  | |   | | '_ \| | | \ \/ /
     \  /\ / (_| | | | | (_| |  | |___| | | | | |_| |>  <
      \/  \/ \__,_|_| |_|\__, |  |_____|_|_| |_|\__,_/_/\_\
                         |___/

   WangLinux 1.0 (Aurora)  ·  amd64

   输入 help-wang 看常用操作，输入 wanginfo 看系统信息
EOF
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone
sed -i 's/^# *\(zh_CN.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen 2>/dev/null || true
locale-gen 2>/dev/null || true
echo 'LANG=zh_CN.UTF-8' > /etc/default/locale
echo 'LANGUAGE=zh_CN:en_US' >> /etc/default/locale
# 用户
id wang >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo wang
echo 'wang:wanglinux' | chpasswd
echo 'root:wanglinux' | chpasswd
echo 'wang ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/010-wang
chmod 440 /etc/sudoers.d/010-wang
# 壁纸（无外部依赖，python3 现画）
python3 - <<'PY' 2>/dev/null || true
import zlib, struct
W, H = 1920, 1080
raw = bytearray()
for y in range(H):
    t = y / H
    raw.append(0)
    raw += bytes((min(255,int(16+70*t)), min(255,int(6+18*t)), min(255,int(38+150*t*t)))) * W
def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(bytes(raw), 6)) + chunk(b'IEND', b''))
open('/usr/share/backgrounds/wanglinux.png', 'wb').write(png)
PY
exit 0
HOOK
chmod +x config/hooks/live/0100-branding.hook.chroot

log "4/5 接入 WangLinux apt 仓库（构建后 ISO 内可直接 apt install）"
if [ -n "$KEYRING" ] && [ -f "$KEYRING" ]; then
  mkdir -p config/includes.chroot/usr/share/keyrings config/includes.chroot/opt/wanglinux-repo config/includes.chroot/etc/apt/sources.list.d
  cp "$KEYRING" config/includes.chroot/usr/share/keyrings/wanglinux-archive-keyring.gpg
  cp -r "$REPO"/. config/includes.chroot/opt/wanglinux-repo/
  cat > config/includes.chroot/etc/apt/sources.list.d/wanglinux.list <<EOF
deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] file:/opt/wanglinux-repo aurora main
EOF
fi

log "5/5 开始构建（下载约 1.5-2.5 GB，40-90 分钟）"
lb build 2>&1 | tee "$WORK/build.log" | grep -E "^(P:|I:|E:)" --line-buffered || true
[ -f live-image-amd64.hybrid.iso ] || { echo "ISO 构建失败，看 $WORK/build.log"; exit 1; }
mkdir -p "$OUT"
mv -f live-image-amd64.hybrid.iso "$OUT/$ISONAME"
cd "$OUT" && sha256sum "$ISONAME" > "$ISONAME.sha256"
log "完成：$OUT/$ISONAME（$(du -h "$ISONAME" | cut -f1)）"

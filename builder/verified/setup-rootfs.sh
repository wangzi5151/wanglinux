#!/bin/bash
# ============================================================================
#  setup-rootfs.sh —— 把 debootstrap 出的裸 rootfs 变成完整的 WangLinux 1.0
#  真实执行：装软件、品牌化、中文、用户、仓库接入、SSH，全部在 chroot 内完成
#  用法: sudo bash setup-rootfs.sh <rootfs路径> <仓库路径> <公钥路径>
# ============================================================================
set -Eeuo pipefail
ROOTFS="${1:?用法: setup-rootfs.sh <rootfs> <repo> <keyring>}"
REPO="${2:-}"
KEYRING="${3:-}"
export DEBIAN_FRONTEND=noninteractive

MIRROR="https://mirrors.ustc.edu.cn/debian"
log() { printf '\n\033[1;35m[setup]\033[0m %s\n' "$*"; }
[ "$(id -u)" -eq 0 ] || { echo "需要 root"; exit 1; }
[ -d "$ROOTFS/usr" ] || { echo "rootfs 不存在: $ROOTFS"; exit 1; }

# ------------------------------------------------------------ 挂载 ----
log "挂载虚拟文件系统"
mount -t proc proc "$ROOTFS/proc" 2>/dev/null || true
mount -t sysfs sys "$ROOTFS/sys" 2>/dev/null || true
mount --bind /dev "$ROOTFS/dev" 2>/dev/null || true
cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
cleanup() {
  umount "$ROOTFS/proc" 2>/dev/null || true
  umount "$ROOTFS/sys" 2>/dev/null || true
  umount "$ROOTFS/dev" 2>/dev/null || true
}
trap cleanup EXIT

ch() { chroot "$ROOTFS" /bin/bash -c "$1"; }

# ------------------------------------------------------------ 源 ----
log "安装 gpgv/apt-utils（用 debootstrap 自带索引，先解决签名验证依赖）"
ch 'apt-get install -y --no-install-recommends gpgv apt-utils debian-archive-keyring' 2>&1 | tail -2 || true

log "写入 USTC apt 源"
rm -f "$ROOTFS/etc/apt/sources.list.d/wanglinux.list"
cat > "$ROOTFS/etc/apt/sources.list" <<EOF
deb $MIRROR bookworm main contrib non-free non-free-firmware
deb $MIRROR bookworm-updates main contrib non-free non-free-firmware
deb $MIRROR-security bookworm-security main contrib non-free non-free-firmware
EOF

log "apt update（首次拉取索引）"
ch 'apt-get update -qq'

# ------------------------------------------------------------ 装软件 ----
log "安装系统基础与网络（约 400-600 MB，耐心等待）"
ch 'apt-get install -y --no-install-recommends \
  systemd-sysv dbus init apt-utils locales tzdata ca-certificates sudo \
  bash-completion man-db manpages cron logrotate less nano procps psmisc \
  iproute2 iputils-ping net-tools dnsutils curl wget openssh-server openssh-client rsync \
  git htop tmux jq file unzip zip xz-utils bzip2 tree lsof bc gnupg lsb-release \
  python3 python3-venv python3-pip ufw fail2ban unattended-upgrades'

# ------------------------------------------------------------ 仓库 ----
if [ -n "$REPO" ] && [ -n "$KEYRING" ] && [ -f "$KEYRING" ]; then
  log "接入 WangLinux apt 仓库并安装自有包"
  mkdir -p "$ROOTFS/usr/share/keyrings" "$ROOTFS/opt/wanglinux-repo"
  cp "$KEYRING" "$ROOTFS/usr/share/keyrings/wanglinux-archive-keyring.gpg"
  cp -r "$REPO"/. "$ROOTFS/opt/wanglinux-repo/"
  cat > "$ROOTFS/etc/apt/sources.list.d/wanglinux.list" <<EOF
deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] file:/opt/wanglinux-repo aurora main
EOF
  ch 'apt-get update -qq'
  ch 'apt-get install -y --no-install-recommends wanglinux-base wanglinux-tools wanglinux-server'
fi

# ------------------------------------------------------------ 品牌 ----
log "写入 WangLinux 品牌标识"
# os-release 已由 wanglinux-base 的 postinst（dpkg-divert + 符号链接）处理，此处不再重复写入
cat > "$ROOTFS/etc/lsb-release" <<'EOF'
DISTRIB_ID=WangLinux
DISTRIB_RELEASE=1.0
DISTRIB_CODENAME=aurora
DISTRIB_DESCRIPTION="WangLinux 1.0 (Aurora)"
EOF
echo "WangLinux 1.0 (Aurora) - Debian bookworm / amd64" > "$ROOTFS/etc/wanglinux-release"
echo wanglinux > "$ROOTFS/etc/hostname"
printf '127.0.0.1\tlocalhost\n127.0.1.1\twanglinux\n' > "$ROOTFS/etc/hosts"
printf 'WangLinux 1.0 \\n \\l\n\n' > "$ROOTFS/etc/issue"
cat > "$ROOTFS/etc/motd" <<'EOF'

   __      ___                  _     _ _
   \ \    / /_ _ _ __   __ _   | |   (_)_ __  _   ___  __
    \ \/\/ / _` | '_ \ / _` |  | |   | | '_ \| | | \ \/ /
     \  /\ / (_| | | | | (_| |  | |___| | | | | |_| |>  <
      \/  \/ \__,_|_| |_|\__, |  |_____|_|_| |_|\__,_/_/\_\
                         |___/

   WangLinux 1.0 (Aurora)  ·  amd64

   输入 help-wang 看常用操作，输入 wanginfo 看系统信息
EOF

# ------------------------------------------------------------ 中文 ----
log "配置中文 locale 与时区"
ch 'sed -i "s/^# *\(zh_CN.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/" /etc/locale.gen && locale-gen'
echo 'LANG=zh_CN.UTF-8' > "$ROOTFS/etc/default/locale"
echo 'LANGUAGE=zh_CN:en_US' >> "$ROOTFS/etc/default/locale"
ch 'ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "Asia/Shanghai" > /etc/timezone'

# ------------------------------------------------------------ 用户 ----
log "创建用户 wang / root 并配置 sudo"
ch 'echo "root:wanglinux" | chpasswd'
if ! ch 'id wang' >/dev/null 2>&1; then
  ch 'useradd -m -s /bin/bash -G sudo wang && echo "wang:wanglinux" | chpasswd'
fi
echo 'wang ALL=(ALL) NOPASSWD: ALL' > "$ROOTFS/etc/sudoers.d/010-wang"
chmod 440 "$ROOTFS/etc/sudoers.d/010-wang"

# ------------------------------------------------------------ SSH ----
log "配置 SSH 与防火墙"
ch 'systemctl enable ssh' 2>/dev/null || true
ch 'systemctl enable cron' 2>/dev/null || true
ch 'ufw allow OpenSSH' 2>/dev/null || true

# ------------------------------------------------------------ 清理 ----
log "清理缓存"
ch 'apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/* /var/tmp/*'

log "完成。rootfs 大小: $(du -sh "$ROOTFS" | cut -f1)"

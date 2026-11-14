#!/bin/bash
# ============================================================================
#  WangLinux 构建共享函数库 —— 被各安装形态 builder 复用
#  提供：日志/错误处理、debootstrap、镜像源、wanglinux 仓库接入、用户设置
# ============================================================================
set -Eeuo pipefail

# ---- 全局参数（均可用环境变量覆盖）----
export WL_SUITE="${WL_SUITE:-bookworm}"
export WL_MIRROR="${WL_MIRROR:-https://mirrors.ustc.edu.cn/debian}"
export WL_REPO_URL="${WL_REPO_URL:-https://wanglinux.github.io/wanglinux-archive}"
export WL_REPO_SUITE="${WL_REPO_SUITE:-aurora}"
export WL_VERSION="${WL_VERSION:-1.0}"
export WL_HOSTNAME="${WL_HOSTNAME:-wanglinux}"
export WL_USER="${WL_USER:-wang}"
export WL_PASS="${WL_PASS:-wanglinux}"
export WL_KEYRING="${WL_KEYRING:-}"   # 可选：本地 keyring 路径（用于 signed-by）

log()  { printf '\n\033[1;35m[wanglinux]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[注意]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[失败]\033[0m %s\n' "$*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "请用 root 运行： sudo bash $0"; }

# debootstrap 最小系统
# 用法: wl_bootstrap <arch> <target-dir> [extra_packages...]
wl_bootstrap() {
  local arch="$1" target="$2"; shift 2
  local pkgs="ca-certificates,apt-transport-https,gnupg,curl,locales${*:+,$*}"
  mkdir -p "$target"
  log "debootstrap ($arch, minbase) → $target"
  debootstrap --arch="$arch" --variant=minbase \
    --include="$pkgs" "$WL_SUITE" "$target" "$WL_MIRROR"
}

# 把 wanglinux 自己的 apt 仓库接入 rootfs
# 用法: wl_add_repo <rootfs>
wl_add_repo() {
  local rootfs="$1"
  local opt="trusted=yes"
  if [ -n "$WL_KEYRING" ] && [ -f "$WL_KEYRING" ]; then
    cp "$WL_KEYRING" "$rootfs/usr/share/keyrings/wanglinux-archive-keyring.gpg"
    opt="signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg"
  else
    warn "未提供 WL_KEYRING，仓库将以 [trusted=yes] 使用（公钥见 distro/archive/）"
  fi
  mkdir -p "$rootfs/etc/apt/sources.list.d"
  printf 'deb [%s] %s %s main\n' "$opt" "$WL_REPO_URL" "$WL_REPO_SUITE" \
    > "$rootfs/etc/apt/sources.list.d/wanglinux.list"
}

# 在 rootfs 里 apt 安装 wanglinux 软件包
# 用法: wl_install <rootfs> <pkg...>
wl_install() {
  local rootfs="$1"; shift
  log "安装 wanglinux 软件包: $*"
  chroot "$rootfs" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
    apt-get update -qq
  chroot "$rootfs" /usr/bin/env DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends "$@"
  chroot "$rootfs" apt-get clean
}

# 设置主机名 / 时区 / 用户
# 用法: wl_setup_base <rootfs>
wl_setup_base() {
  local rootfs="$1"
  echo "$WL_HOSTNAME" > "$rootfs/etc/hostname"
  printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n' "$WL_HOSTNAME" > "$rootfs/etc/hosts"
  ln -sf /usr/share/zoneinfo/Asia/Shanghai "$rootfs/etc/localtime" 2>/dev/null || true
  echo "Asia/Shanghai" > "$rootfs/etc/timezone"
  echo 'LANG=zh_CN.UTF-8' > "$rootfs/etc/default/locale"
  echo 'LANGUAGE=zh_CN:en_US' >> "$rootfs/etc/default/locale"
  chroot "$rootfs" /bin/sh -c "
    id '$WL_USER' >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo '$WL_USER'
    echo '$WL_USER:$WL_PASS' | chpasswd
    echo 'root:$WL_PASS' | chpasswd
  "
}

# 清理 rootfs 中的构建残留（减小体积）
# 用法: wl_cleanup <rootfs>
wl_cleanup() {
  local rootfs="$1"
  rm -rf "$rootfs/var/lib/apt/lists/"* "$rootfs/var/cache/apt/archives/"*.deb \
         "$rootfs/tmp/"* "$rootfs/var/tmp/"* 2>/dev/null || true
  find "$rootfs/var/log" -type f -delete 2>/dev/null || true
}

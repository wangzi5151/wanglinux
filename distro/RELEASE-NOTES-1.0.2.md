# WangLinux 1.0.2 (Aurora) 发布说明 — amd64 实测构建

日期：2026-11 · 基础：Debian 12 (bookworm) · 套件：`aurora`

这一版不再只是"脚本 + 元包"，而是**从 debootstrap 真实拉取 Debian、编译 6 个 .deb、签名 apt 仓库、封装 rootfs / 云镜像 / Live ISO** 的完整 amd64 构建。

## 交付产物（release v1.0.2）

| 文件 | 大小 | 说明 |
|---|---|---|
| `wanglinux-1.0-amd64.iso` | 441M | 桌面 Live ISO（Xfce + 中文 + Firefox，`file` 验证 `bootable`） |
| `wanglinux-1.0-amd64-rootfs.tar.gz` | 179M | 服务器根文件系统（267 个包，SSH/ufw/fail2ban/unattended-upgrades/cloud-init） |
| `wanglinux-1.0-amd64-cloud.qcow2` | 712M(虚拟 2G) | 云镜像（ext4 根盘 + cloud-init，NoCloud/OpenStack/EC2） |
| `pool/*.deb` | 6 个 | wanglinux-base / theme / desktop / tools / server / devel |
| `archive/` | — | 完整签名 apt 仓库（`InRelease` + `Release.gpg`，`Good signature`） |
| `wanglinux-archive-keyring.gpg` | 1.4K | 仓库签名公钥（armor） |

## 6 个自研软件包

```
wanglinux-base     1.0.2-1~aurora3  all  发行版身份 / wanginfo / help-wang / wanglinux-version / motd
wanglinux-theme    1.0.1-1~aurora2  all  Aurora GTK 主题 / 壁纸 / LightDM 配置
wanglinux-desktop  1.0.2-1~aurora3  all  元包：XFCE + 中文 + 输入法 + 浏览器
wanglinux-tools    1.0.0-1~aurora1  all  wangfetch / wang-switch-mirror / wang-setup-server
wanglinux-server   1.0.0-1~aurora1  all  元包：SSH / ufw / fail2ban / unattended-upgrades
wanglinux-devel    1.0.0-1~aurora1  all  元包：C/C++/Python 工具链 + git/cmake/ninja/gdb
```

全部 `Architecture: all`（纯脚本/数据），amd64 与 arm64 通用。

## 本环境实测验证

- ✅ `debootstrap --variant=minbase` 真实拉取 Debian 12.15（273M 底座 → 498M 完整系统）
- ✅ 6 个 `.deb` `dpkg-deb` 构建，元数据完整可安装
- ✅ apt 仓库 `apt-ftparchive` + GPG 签名，`apt update` 显示 `Good signature`
- ✅ chroot 内 `wanginfo` / `wangfetch` / `help-wang` 运行正常，识别 267 个包；从 USTC 源真实安装 `neofetch`
- ✅ `apt install wanglinux-desktop` 依赖链完整解析（Xfce + 驱动全套）
- ✅ 容器镜像 `docker import` + `docker run` 实测通过
- ✅ qcow2 内 cloud-init / sshd / wanginfo / os-release 文件齐全
- ✅ ISO `mksquashfs + xorriso + isolinux` 组装，`file` 确认 `bootable`

## 签名密钥

```
WangLinux Archive Signing Key <archive@wanglinux.local>
fingerprint D1FA722270D95679E947C70906CB40B44353A625   (rsa3072)
```

## 已知限制（如实说明）

1. 构建机无 loop/nbd 设备、禁用 `mknod`，因此：
   - 云镜像为**单 ext4 根盘**（适合云平台挂根盘或 `-kernel` 启动），无内置分区表/引导；
   - ISO 由手工 `mksquashfs + xorriso + isolinux` 组装，EFI 双启动需在有 loop 的环境跑 `builder/verified/build-iso.sh` 生成完整版。
2. arm64/树莓派镜像未在本环境重新构建与真机验证；`builder/arm64`、`pi/` 脚本保留，供对应硬件实测。
3. 仓库签名私钥仍位于构建机，正式发布应迁到离线签名或 CI secret（沿用 1.0 说明）。

## 复现

```bash
# 1. 拉 Debian 12 基础
sudo debootstrap --variant=minbase --include=ca-certificates,locales,gnupg \
  bookworm /opt/rootfs https://mirrors.ustc.edu.cn/debian/
# 2. 注入为完整 WangLinux（含 6 个自研包 + 签名仓库）
sudo bash builder/verified/setup-rootfs.sh /opt/rootfs distro/archive distro/archive/wanglinux-archive-keyring.gpg
# 3. 桌面 Live ISO（需有 loop 设备的环境）
sudo bash builder/verified/build-iso.sh distro/archive distro/archive/wanglinux-archive-keyring.gpg
```

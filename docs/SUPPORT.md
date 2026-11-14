# WangLinux 支持矩阵

WangLinux 不再只是树莓派发行版——它是一套「一个 Debian 12 地基 + 多个安装形态」的完整系统。
同一套软件包、同一条 `build.sh` 入口，产出下面这些形态。

## 安装形态（安装包）

| 形态 | 架构 | 构建命令 | 产物 | 适用场景 |
|---|---|---|---|---|
| 桌面 ISO | amd64 | `./build.sh iso` | `.iso`（UEFI+BIOS） | x86_64 电脑装机 / U 盘 |
| 云镜像 | amd64 / arm64 | `ARCH=arm64 ./build.sh qcow2` | `.qcow2`（cloud-init） | 云主机 / KVM / QEMU |
| 通用 rootfs | amd64 / arm64 / armhf / riscv64 | `ARCH=arm64 ./build.sh rootfs` | `.tar.gz` | chroot / nspawn / 定制起点 |
| 容器镜像 | amd64 / arm64 | `ARCH=arm64 ./build.sh container` | `.tar`（OCI） | Docker / Podman |
| WSL 导入包 | amd64 | `./build.sh wsl` | `.tar.gz` | Windows 子系统 |
| 通用 arm64 镜像 | arm64 | `FLAVOR=desktop ./build.sh arm64-image` | `.img.gz`（GPT+EFI） | ARM 服务器 / UEFI 板卡 |
| 树莓派镜像 | arm64 | `./build.sh pi` | `.img.gz` | Pi 3/4/400/CM4（专用引导） |

## 软件包

| 包名 | 类型 | 作用 |
|---|---|---|
| `wanglinux-base` | 基础 | 发行版身份（os-release/motd）+ wanginfo/help-wang/wanglinux-version |
| `wanglinux-tools` | 工具 | wangfetch / wang-switch-mirror / wang-setup-server |
| `wanglinux-theme` | 主题 | GTK 主题、壁纸、LightDM 配置 |
| `wanglinux-desktop` | 元包 | XFCE 桌面 + 中文 + 浏览器（整桌体验） |
| `wanglinux-server` | 元包 | SSH + 防火墙 + fail2ban + 自动安全更新（无头服务器） |
| `wanglinux-devel` | 元包 | C/C++/Python 全工具链 + 调试（开发机） |

## 架构支持

| 架构 | 状态 |
|---|---|
| amd64 (x86_64) | ✅ ISO / rootfs / 容器 / WSL / qcow2 |
| arm64 | ✅ rootfs / 容器 / qcow2 / 通用镜像 / 树莓派镜像 |
| armhf | 🟡 rootfs（未广泛测试） |
| riscv64 | 🟡 rootfs（实验性，需镜像源支持） |

> 各形态都可用环境变量覆盖默认参数（镜像源 `WL_MIRROR`、仓库地址 `WL_REPO_URL`、
> 输出目录 `OUT`、架构 `ARCH`、桌面/服务器变体 `FLAVOR`）。见 `./build.sh help`。

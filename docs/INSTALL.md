# WangLinux 安装指南

## 0. 构建机要求

- Debian 12 / Ubuntu 22.04+ 的 root 权限环境（各脚本内部用 debootstrap + dpkg）
- 需要联网（默认走 USTC 镜像，可用 `WL_MIRROR` 覆盖）
- 各形态依赖：`debootstrap`、`dpkg-dev`；qcow2 额外需要 `qemu-utils`；
  arm64 镜像需要 `dosfstools` `mtools` `grub-efi-arm64-bin`；ISO 需要 `live-build`
  （脚本会自动安装，或参照 `builder/` 下各脚本头部注释）

## 1. 一条命令构建

```bash
git clone https://github.com/wangzi5151/wanglinux.git && cd wanglinux
./build.sh help          # 查看所有目标
./build.sh deb           # 只打 6 个 .deb 包（最快，验证打包链路）
./build.sh rootfs        # 通用 rootfs tarball
./build.sh container     # OCI 容器镜像
./build.sh wsl           # Windows WSL 包
ARCH=arm64 ./build.sh qcow2        # arm64 云镜像
FLAVOR=desktop ./build.sh arm64-image   # 带桌面的通用 arm64 镜像
```

## 2. 各形态安装

### ISO（amd64）
Rufus/balenaEtcher 写入 U 盘 → 开机选 U 盘。账号 `wang / wanglinux`。

### 云镜像（qcow2）
```bash
qemu-system-x86_64 -m 2048 \
  -drive file=wanglinux-cloud-amd64-1.0.qcow2,format=qcow2 \
  -kernel vmlinuz -initrd initrd.img -append "root=/dev/sda ro console=ttyS0"
```
云上可配合 cloud-init seed（`NoCloud`）注入用户与 SSH 密钥。

### 容器镜像
```bash
docker import wanglinux-oci-amd64-1.0.tar wanglinux:1.0
docker run -it wanglinux:1.0 /bin/bash
```

### WSL
```powershell
wsl --import WangLinux C:\WangLinux .\wanglinux-wsl-1.0.tar.gz
wsl -d WangLinux
```

### 通用 arm64 镜像
```bash
gunzip -c wanglinux-arm64-1.0.img.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 树莓派镜像
见 [pi/README.md](../pi/README.md)。

## 3. 安装后（所有形态通用）

```bash
wangfetch                 # 系统信息
wang-switch-mirror        # 切换 apt 镜像
sudo wang-setup-server    # 服务器加固（服务器形态）
passwd                    # 立即改密码！
```

默认账号 `wang / wanglinux`（root 同密码），首次登录请务必改密。

## 4. 升级与软件包

```bash
# 加入 wanglinux 自己的仓库（详见 distro/README.md）后：
sudo apt update
sudo apt install wanglinux-server   # 服务器能力
sudo apt install wanglinux-devel    # 开发工具链
sudo apt install wanglinux-desktop  # 桌面
```

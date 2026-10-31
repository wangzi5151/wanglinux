# WangLinux

一个自己搭出来的 Linux 发行版：**Debian 12 做地基，加中文支持、树莓派镜像、自己的软件仓库和更新源**。

不是 fork，也不是换皮的 Ubuntu——底下每一块（镜像、包、签名、仓库）都是这个仓库里的脚本从零装出来的。

**最新可用的东西**：树莓派 3 / 4 / 400 / CM4 都能跑的系统镜像，下载解压、写进 SD 卡、插上开机就有桌面。

---

## 一、我要下载哪个？

| 想干什么 | 下载 | 大小 |
|---|---|---|
| **在树莓派上用图形桌面**（推荐，多数人下载这个） | [pi-1.0-desktop](https://github.com/wangzi5151/wanglinux/releases/tag/pi-1.0-desktop) 里的 `wanglinux-pi-1.0-desktop.img.gz` | 1.2 GB |
| 在树莓派上只要一个干净的命令行系统 | [pi-1.0](https://github.com/wangzi5151/wanglinux/releases/tag/pi-1.0) 里的 `wanglinux-pi-1.0.img.gz` | 637 MB |
| 自己写程序、要装我的软件包 | `wanglinux-base` / `wanglinux-theme` / `wanglinux-desktop` 三个 `.deb` | 各几十 KB |
| 想看原理、自己改 | 直接 clone 这个仓库 | — |

> 只想试试桌面的话：**下第一个**，别管其他的。

---

## 二、怎么装进 SD 卡（三步）

**1. 下载上面的 `.img.gz`**

**2. 写卡**

最简单——装 [Raspberry Pi Imager](https://www.raspberrypi.com/software/)，点 **"Choose OS" → 拉到最下面 "Use custom image"**，选你下载的那个 `.gz`（不用解压，它认得），再选你的 SD 卡，点 Write。

想做命令行党也行（Linux / macOS，把 `/dev/sdX` 换成你的卡，**别选错盘，会清空**）：

```bash
gunzip wanglinux-pi-1.0-desktop.img.gz
sudo dd if=wanglinux-pi-1.0-desktop.img of=/dev/sdX bs=4M status=progress conv=fsync
```

**3. 插卡、接 HDMI 和键盘、通电**

第一次开机要 30 秒~1 分钟（它在自动把系统扩展到整张卡）。屏幕会黑一阵，别拔电。

---

## 三、开机之后

| | |
|---|---|
| 主机名 | `wanglinux` |
| 用户名 | `wang` |
| 密码 | `wanglinux` |
| root 密码 | `wanglinux` |
| SSH | 已经开着：`ssh wang@wanglinux.local` |

- **桌面版**：自动登录直接进 XFCE 桌面，有中文、有壁纸。
- **控制台版**：一个黑底白字的终端，敲 `startx` 没有东西，要桌面得自己装（见下）。

**开机第一件事，改密码**：

```bash
passwd              # 改自己的
sudo passwd root    # 改 root 的
```

控制台版想要桌面，一条命令：

```bash
sudo apt update && sudo apt install wanglinux-desktop
sudo systemctl enable lightdm && sudo reboot
```

---

## 四、出问题了怎么办

| 现象 | 原因 / 办法 |
|---|---|
| 黑屏、彩虹屏、卡在开机画面 | 先换**足额 5V 3A 的电源**和一张好卡；还不行就看串口日志（见下） |
| 键盘没反应 | 换 USB 口；Pi 4 请插蓝色 USB3 口 |
| 中文显示成方块 | 在**文本控制台**里这是正常的——控制台只有西文字形。进了图形桌面就正常 |
| 提示 `apt update` 失败 | 先看网络：`ping mirrors.ustc.edu.cn`；换源见 `distro/` 里的说明 |
| 屏幕分辨率不对 / 无显示 | 改卡上 `config.txt`，加 `hdmi_safe=1` 试 |

**要我看日志**：串口已经开好了（115200 8N1，接 GPIO 14/15 和地）。没有串口线的话，把卡拔下来，在 `config.txt` 里把 `console=serial0,115200` 留着，用 USB 转 TTL 就能看到它在哪一步停住。

---

## 五、它是怎么造出来的（给好奇的人）

```
distro/debootstrap.sh     → 从 Debian 12 装一个最小 rootfs（用中国镜像）
distro/build-*.sh         → 把软件包打成 .deb
distro/sign-repo.sh       → apt-ftparchive + gpg 签名，生成自己的 apt 仓库
pi/assemble.sh            → 把 rootfs + 内核 + 固件拼成可烧录的 SD 镜像
kernel/build-kernel.sh    → 从源码编译内核（实验性，镜像里用的是 Debian 官方内核）
iso/                      → x86 安装盘（实验性）
```

两个卡过我的坑，都写在脚本注释里了：

1. 构建机没有 loop 设备，所以 ext4 用 `mke2fs -d` 直接填充、FAT 用 mtools 造、分区表拿 python 手写。
2. 在这种环境里 `cp -a` 会把硬链接变成**指向宿主绝对路径的符号链接**，镜像里全是断链——脚本里有专门的修复步骤。

---

## 六、老实说的限制

- 树莓派镜像**没有在真机上验证过**（构建机是一台手机上的 chroot，手里没有 Pi）。能起就是运气好，起不来请把串口日志发我，我改。
- 只支持 Pi 3 / 4 / 400 / CM4。**Pi 5 不行**（要另一套固件和内核）。
- 内核是 Debian 官方 arm64 内核，不是自己编的。自己编的那套在 `kernel/`，没在这镜像里用过。
- x86 安装盘是实验性的，装完能不能用不保证，**别拿它装你的工作机**。
- 桌面里没装浏览器和办公软件（能省 800MB）。要的话：`sudo apt install firefox-esr`。

---

## 七、许可

代码 MIT。里面装的 Debian 软件包各自遵守原许可。字体（文泉驿）是 GPL + 字体例外。

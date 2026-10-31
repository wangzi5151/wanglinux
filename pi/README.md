# 树莓派镜像（WangLinux 1.0 Aurora）

两个版本，按需选一个：

| 版本 | 文件 | 大小 | 里面有什么 |
|---|---|---|---|
| **桌面版**（推荐） | `wanglinux-pi-1.0-desktop.img.gz` | 1.2 GB | XFCE 桌面 + 中文 + 自动登录 |
| 控制台版 | `wanglinux-pi-1.0.img.gz` | 637 MB | 纯命令行，654 个包里的最小集合 |

支持 **Pi 3 / 3B+ / 4 / 400 / CM4**（arm64）。**Pi 5 不支持**（需要另一套固件与内核）。

## 1. 写卡

**图形界面（最省事）**：装 [Raspberry Pi Imager](https://www.raspberrypi.com/software/) → Choose OS → 最下面 **Use custom image** → 选下载的 `.gz`（不需要先解压）→ 选 SD 卡 → Write。

**命令行**：

```bash
gunzip wanglinux-pi-1.0-desktop.img.gz
sudo dd if=wanglinux-pi-1.0-desktop.img of=/dev/sdX bs=4M status=progress conv=fsync
```

（`/dev/sdX` 换成你的卡；Windows 上用 Imager 就行，别用 Rufus 的 DD 模式以外选项。）

## 2. 第一次开机

插卡、接 HDMI 和键鼠、通电。第一次开机会自动把系统扩展到整张卡，屏幕黑 30 秒到 1 分钟是正常的。

| | |
|---|---|
| 主机名 | `wanglinux`（`wanglinux.local`） |
| 用户 | `wang` / `wanglinux` |
| root | `wanglinux` |
| SSH | 已开启 |
| 串口控制台 | `serial0`，115200 8N1 |

**进系统先改密码**：

```bash
passwd
sudo passwd root
```

桌面版会自动登录进 XFCE。控制台版要桌面：

```bash
sudo apt update && sudo apt install wanglinux-desktop
sudo systemctl enable lightdm && sudo reboot
```

## 3. 镜像里到底有什么

- Debian 12 (bookworm) arm64，654 个包
- 内核 `6.1.0-50-arm64`（Debian 官方 arm64 内核），initramfs 含 `sdhci-iproc` / `bcm2835` 等 SD 卡驱动
- 中文字体（文泉驿正黑、Noto Emoji）+ 已生成 `zh_CN.UTF-8` locale
- 桌面版：XFCE 4.18 + lightdm（自动登录 `wang`）+ 壁纸
- 自己的身份：`/etc/os-release`、`wanginfo`、`wanglinux-version`、`help-wang`
- 自己的 apt 源：`/etc/apt/sources.list.d/wanglinux.list` → `file:/srv/wanglinux-repo`（已签名）
- 首次开机自动扩容根分区的 systemd 服务

## 4. 出问题

| 现象 | 怎么办 |
|---|---|
| 黑屏 / 彩虹屏 / 卡在四个树莓 | 换 5V 3A 电源和好卡；接串口看日志；`config.txt` 里加 `hdmi_safe=1` |
| 桌面起不来（黑屏一个鼠标箭头） | SSH 进去看 `journalctl -u lightdm -b` |
| 中文显示方块 | 文本控制台必然如此（只有西文字形）；图形终端里正常 |
| 键盘/鼠标不动 | 换 USB 口，Pi 4 用蓝色口 |

串口日志：`enable_uart=1` 已开，GPIO14(TX)/GPIO15(RX)/GND，115200 8N1。启动失败请把日志贴出来。

## 5. 想自己重做一遍

```bash
SRC=/opt/wl-pi bash assemble.sh
```

关键参数（脚本里可改）：

```
MBR disk signature 0x57414e47 → PARTUUID 57414e47-01 / -02（与 /etc/fstab 对应）
p1: 起 8192 扇区,  524288 扇区 = 256 MiB, FAT32, 卷标 BOOT   → /boot/firmware
p2: 起 532480 扇区, 4600MiB, ext4, 卷标 WANGLINUX          → /
```

没有 loop 设备也能做：ext4 用 `mke2fs -d` 填充，FAT 用 mtools，分区表用 python 写。
**注意**：PRoot 环境下 `cp -a` 会把硬链接变成指向宿主绝对路径的符号链接，必须先修再打包（脚本第 1 步就在干这个）。

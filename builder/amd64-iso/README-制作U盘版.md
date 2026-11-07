# WangLinux 1.0 (amd64) — U 盘版制作说明

目标：产出一个 **可引导的 ISO**，用 Rufus 写进 U 盘，在 Windows 电脑上开机按 F12 选 U 盘，
进入你自己的 WangLinux（XFCE 桌面 + 中文 + 一百多个预装工具），**全程不动、不影响硬盘上的 Windows**。

> 为什么必须由你在电脑上跑一遍：这台手机是 arm64，造不出 x86_64 的二进制和引导器。
> 所以我把整套构建脚本写好了，你在电脑上执行一条命令即可产出成品。

---

## 一、选一条路线

| 路线 | 适合谁 | 准备时间 | 说明 |
|---|---|---|---|
| **A. WSL2 + Ubuntu**（推荐） | Windows 10/11 | 约 20 分钟 | 最省事，不需要 Docker |
| **B. Docker Desktop** | 有 Docker 的机器 | 约 10 分钟 | `bash build-in-docker.sh` 一条命令 |
| **C. 真机 Debian 12 / Ubuntu** | 已有 Linux 机器 | 0 分钟 | 直接 `sudo bash build-wanglinux-amd64.sh` |

---

## 二、路线 A：Windows + WSL2（推荐）

1. **管理员 PowerShell** 里执行：
   ```powershell
   wsl --install -d Ubuntu-22.04
   ```
   装完重启，设置 Ubuntu 用户名密码。

2. 打开 Ubuntu 终端，把脚本拷进去（两种办法任选）：
   - 把两个 `.sh` 文件下载到 `C:\Users\你的名字\Downloads`，然后在 Ubuntu 里：
     ```bash
     cp /mnt/c/Users/你的名字/Downloads/build-wanglinux-amd64.sh ~/
     chmod +x ~/build-wanglinux-amd64.sh
     ```
   - 或直接新建文件粘贴内容：`nano ~/build-wanglinux-amd64.sh`

3. 给 WSL 留够空间（需要 **15 GB 空闲**），确认：
   ```bash
   df -h /
   ```

4. 开始构建（**40–90 分钟**，可最小化窗口干别的）：
   ```bash
   sudo bash ~/build-wanglinux-amd64.sh
   ```

5. 完成后 ISO 在 `/build/wanglinux-1.0-amd64.iso`，拷到 Windows：
   ```bash
   cp /build/wanglinux-1.0-amd64.iso /mnt/c/Users/你的名字/Downloads/
   ```

---

## 三、路线 B：Docker（Windows / macOS）

装好 [Docker Desktop](https://www.docker.com/products/docker-desktop/) 后，把两个脚本放同一目录：

- **Windows**：打开 PowerShell 进到该目录，执行
  ```powershell
  bash build-in-docker.sh
  ```
- **macOS / Linux**：
  ```bash
  bash build-in-docker.sh
  ```

ISO 会出现在 `./out/` 目录。容器必须 `--privileged`（脚本里已经写了）。

---

## 四、写入 U 盘

1. 用 [Rufus](https://rufus.ie)（免费）→ 选择你的 U 盘（**≥ 8 GB，会被清空**）
2. 「引导类型」选 ISO，「分区类型」选 **GPT**，「目标系统」选 **UEFI（非 CSM）**
3. 开始 → 等待写完
4. 重启电脑，开机时按 **F12 / F8 / F11 / Esc**（不同品牌不同）打开启动菜单，选 `UEFI: 你的U盘`
5. 直接进入 WangLinux 桌面，自动登录 `wang`

**进入后**：左下角菜单有浏览器、文件管理器、终端；中文输入法 **Ctrl+空格** 切换；
终端里输入 `wanginfo` 看系统信息，`help-wang` 看常用操作。
默认密码：`wang` / `wanglinux`（root 同密码）。

---

## 五、想让改动保存下来（持久化，可选）

默认是 Live 模式，重启就还原。要"插上就是自己的系统"：

1. 写盘后用 Windows 的磁盘管理 / DiskGenius，在 U 盘上**新建一个分区**（剩余空间，ext4）
2. 用 Linux 或 GParted 给它打上卷标 `persistence`
3. 分区根目录放一个文件 `persistence.conf`，内容一行：
   ```
   / union
   ```
4. 之后开机自动挂载该分区，`/home`、装的软件、改的配置全部保留

（更省事的替代方案：直接装 Ventoy 到 U 盘，把 ISO 丢进去，Ventoy 自带持久化菜单。）

---

## 六、出错怎么办

| 现象 | 原因 / 处理 |
|---|---|
| `E: Unable to locate package xxx` | 某个包名在 bookworm 不存在。编辑脚本里 `wanglinux-core.list.chroot` 附近的清单，删掉那一行再跑 |
| `lb build` 中途失败 | 看 `/build/wanglinux-iso/build.log` 最后的 `E:` 行；国内网络建议保持 ustc 镜像设置 |
| 磁盘不足 | 至少 15 GB；`WORK=/其他盘/wanglinux-iso` 可换目录 |
| 写盘后开不了机 | 确认 BIOS 里**关闭 Secure Boot**（或选允许第三方签名），U 盘按 **UEFI** 模式启动 |
| 卡在 `Loading ...` | 启动菜单按 `e`，在 `quiet splash` 后加 `nomodeset` 再启动（显卡兼容问题） |

> **诚实说明**：这套脚本是按 Debian live-build 官方规范写的，但我只能在 arm64 沙盒里做语法与逻辑校验，
> 无法在 x86 上实跑一遍验证引导。第一次跑若有小问题，把报错行发我，我改脚本。

---

## 七、顺便说：arm64 版（已经做好）

手机上已经产出 `wanglinux-1.0-arm64-rootfs.tar.gz`（350 MB，294 个包）。
它适合：**树莓派 4/5、ARM 笔记本、安卓手机（Termux + chroot/proot）**。
要"树莓派可启动镜像"（`.img`）我也可以再给一套打包脚本，说一声即可。

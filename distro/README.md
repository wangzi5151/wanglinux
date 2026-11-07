# WangLinux 发行版工程（1.0 "Aurora"）

一个真正可安装、可升级的 Debian 12 衍生版：
- `pkgsrc/`  自有软件包源码（wanglinux-base / wanglinux-theme / wanglinux-desktop）
- `archive/`  构建好的签名 APT 仓库（可直接 `apt update` 使用）
- `build-repo.sh`  一条命令重建仓库（生成 deb → Packages → Release → InRelease）
- `../wanglinux-kernel/`  自有内核构建套件
- `RELEASE-NOTES-1.0.md`  这一版到底做了什么、没做什么

## 快速构建
```bash
sudo bash build-repo.sh          # 在 Debian 12 arm64/amd64 容器或 rootfs 内
```

## 快速安装（客户端）
```bash
sudo cp archive/wanglinux-archive-keyring.gpg /usr/share/keyrings/
echo "deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] \
https://wanglinux.github.io/wanglinux-archive aurora main" \
  | sudo tee /etc/apt/sources.list.d/wanglinux.list
sudo apt update && sudo apt install wanglinux-base wanglinux-theme
```

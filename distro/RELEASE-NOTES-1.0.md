# WangLinux 1.0 "Aurora" 发布说明

发布日期：2025-Q4 · 基础：Debian 12 (bookworm) · 套件：`aurora`

---

## 这一版真正做成了什么

| 能力 | 状态 | 怎么验证 |
|---|---|---|
| 自有 APT 仓库（签名） | ✅ 可用 | `apt update` 从 `file:`/`https:` 取到 `aurora/main`，`InRelease` 验签通过 |
| 自有软件包 | ✅ 3 个 | `wanglinux-base` / `wanglinux-theme` / `wanglinux-desktop` |
| 发行版身份（非贴图） | ✅ | `/etc/os-release`、`/usr/lib/os-release` 由 `wanglinux-base` 通过 **dpkg-divert** 接管，卸载后自动还原 Debian 的 |
| 版本化 / 升级路径 | ✅ 已验证 | 1.0.0 → 1.0.1 → 1.0.1-2 连续 `apt install`/`--only-upgrade` 升级成功，未破坏系统 |
| 元包定义"一版发行版" | ✅ | `wanglinux-desktop` 依赖解析可拉起 **1086** 个包（整桌 XFCE + 中文 + 浏览器） |
| 自定义内核 | 🚧 构建套件已就绪，未编译 | `wanglinux-kernel/build-kernel.sh`，见下 |
| 独立引导（无宿主内核） | 🚧 树莓派镜像路线已备料 | 需要 x86/树莓派实机验证 |

## 包清单

```
wanglinux-base       1.0.1-2~aurora2   all
   /usr/bin/wanginfo  /usr/bin/wanglinux-version  /usr/bin/help-wang
   /usr/share/wanglinux/{os-release,release,motd}
   dpkg-divert 接管 /etc/os-release、/usr/lib/os-release

wanglinux-theme      1.0.1-1~aurora2   all
   /usr/share/wallpapers/wanglinux/aurora.png        (1920x1080，程序生成)
   /usr/share/themes/Aurora/gtk-3.0/gtk.css          (Aurora 配色覆盖)
   /etc/lightdm/lightdm-gtk-greeter.conf.d/50-wanglinux.conf
   /etc/xdg/autostart/wang-wallpaper.desktop

wanglinux-desktop    1.0.1-1~aurora2   all  (meta)
   Depends: wanglinux-base >= 1.0.0, wanglinux-theme >= 1.0.0,
            task-xfce-desktop, lightdm, firefox-esr | chromium,
            fonts-noto-cjk, fcitx5, fcitx5-chinese-addons, ...
```

## 仓库结构与使用

```
archive/
├── dists/aurora/
│   ├── InRelease  Release  Release.gpg
│   └── main/binary-{all,amd64,arm64}/{Packages,Packages.gz}
├── pool/main/wang/{wanglinux-base,wanglinux-theme,wanglinux-desktop}/*.deb
├── wanglinux-archive-keyring.gpg
└── README.txt
```

```bash
sudo cp wanglinux-archive-keyring.gpg /usr/share/keyrings/
echo "deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] \
https://wanglinux.github.io/wanglinux-archive aurora main" \
  | sudo tee /etc/apt/sources.list.d/wanglinux.list
sudo apt update && sudo apt install wanglinux-desktop
```

包是 `Architecture: all`（纯脚本/数据），**同一份仓库 arm64 与 amd64 通用**。

## 与 Debian 的关系（不美化）

- 用户态仍然是 Debian 12 的包，我们没有替换 glibc/核心工具链，也没有自己的安全团队。
- 现在这版的正确定位是：**一个带自有身份、自有仓库、自有元包与升级通道的 Debian 衍生版（derivative）**，
  而不是从零自举的独立发行版。
- 达成"独立"还差三步：自己的内核（已备构建脚本）、自己的引导与镜像流水线、以及跟踪上游安全更新的
  自动重建（`aurora-security` 套件 + 定时 rebuild）。

## 升级 / 回滚

```bash
wanglinux-version              # 看当前版本与源
sudo apt update && sudo apt full-upgrade
sudo apt install wanglinux-base=1.0.0-1~aurora1   # 回滚单个包（旧版本仍在 pool 中时有效）
```

## 已知问题

1. `apt` 会提示 `diverting file ... from an Essential package with rename is dangerous` —— 这是 base-files
   为 Essential 包时的正常告警，卸载 `wanglinux-base` 会还原；将来应改为 fork `base-files`。
2. 仓库签名私钥目前放在构建机的 `/srv/wanglinux-gnupg`，正式发布必须迁到离线签名或 CI secret。
3. 首次 `apt update` 若只用 `file:` 源且未装 keyring，请退化为 `[trusted=yes]`（README.txt 里有）。

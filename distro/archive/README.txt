WangLinux "aurora" 软件仓库
=================================
套件: aurora   组件: main   架构: amd64 all
包含: wanglinux-base wanglinux-theme wanglinux-desktop
      wanglinux-tools wanglinux-server wanglinux-devel
URL : https://github.com/wangzi5151/wanglinux
签名: WangLinux Archive Signing Key <archive@wanglinux.local>
      fingerprint D1FA722270D95679E947C70906CB40B44353A625

安装方式一（已导入公钥）:
  sudo cp wanglinux-archive-keyring.gpg /usr/share/keyrings/
  echo "deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] https://wangzi5151.github.io/wanglinux aurora main" \
    | sudo tee /etc/apt/sources.list.d/wanglinux.list
  sudo apt update && sudo apt install wanglinux-desktop

安装方式二（本地路径 / 未签名时）:
  echo "deb [trusted=yes] file:/opt/wanglinux-repo aurora main" \
    | sudo tee /etc/apt/sources.list.d/wanglinux.list

说明：6 个包均为 Architecture: all（纯脚本/数据），amd64 与 arm64 通用；
本目录 pool 采用标准 Debian 布局 pool/main/w/<pkg>/。

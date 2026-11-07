WangLinux "aurora" 软件仓库
=================================
套件: aurora   组件: main   架构: amd64 arm64 all
包含: wanglinux-base wanglinux-theme wanglinux-desktop
URL : https://wanglinux.github.io/wanglinux-archive

安装方式一（已导入公钥）:
  sudo cp wanglinux-archive-keyring.gpg /usr/share/keyrings/
  echo "deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] https://wanglinux.github.io/wanglinux-archive aurora main" \
    | sudo tee /etc/apt/sources.list.d/wanglinux.list
  sudo apt update && sudo apt install wanglinux-desktop

安装方式二（本地路径 / 未签名时）:
  echo "deb [trusted=yes] file:/srv/wanglinux-repo aurora main" \
    | sudo tee /etc/apt/sources.list.d/wanglinux.list

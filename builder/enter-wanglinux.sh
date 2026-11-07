#!/bin/sh
# 进入 WangLinux 1.0 (arm64) —— 在 Kelivo 沙盒里运行此脚本
# 用法： sh /workspace/enter-wanglinux.sh            进入交互 shell
#        sh /workspace/enter-wanglinux.sh "命令..."  执行单条命令
R=/opt/wanglinux

[ -d "$R/usr/bin" ] || { echo "根文件系统不存在：$R（可从 tar 包恢复）"; exit 1; }

# 沙盒禁止 mknod，用普通文件代理 /dev 节点
for n in null zero random urandom tty; do
  [ -e "$R/dev/$n" ] || { : > "$R/dev/$n"; chmod 666 "$R/dev/$n"; }
done
mkdir -p "$R/proc" "$R/sys" "$R/tmp" "$R/run"

if [ -n "$1" ]; then
  exec chroot "$R" /bin/bash -lc "$*"
else
  exec chroot "$R" /bin/bash -l
fi

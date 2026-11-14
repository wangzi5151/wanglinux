# live-build 沙箱环境修复说明

本环境禁用了 `mknod` 系统调用，导致 debootstrap 无法在 chroot 内创建 `/dev/null`
等设备节点，进而让 live-build 的 chroot 阶段 `apt update` 报
`gpgv required but neither seems installed`（误导性错误，实际是 apt-key 无法写 /dev/null）。

**修复**：修改 `/usr/lib/live/build/lb_chroot_devpts`，在挂载 /dev/pts 之前 bind mount 宿主 /dev：

```sh
# install 分支，mount devpts 前加：
${LB_ROOT_COMMAND} mount --bind /dev chroot/dev 2>/dev/null || true

# remove 分支，umount devpts 后加：
${LB_ROOT_COMMAND} umount chroot/dev 2>/dev/null || true
```

## 本轮迭代解决的其他问题

| # | 问题 | 解决 |
|---|---|---|
| 1 | `--debootstrap-options` 不存在（live-build 3.0 改名） | 改用 `--bootstrap-flavour` / `--apt-options` |
| 2 | gpgv 缺失 → apt update 失败 | 根因是 /dev/null 缺失，bind mount /dev 修复 |
| 3 | `--apt-options --allow-insecure-repositories` 冲突 | 弃用 |
| 4 | live-build 固件检测下载 `Contents-amd64.gz` 404 | `--firmware-chroot false --firmware-binary false` |
| 5 | 内核包名拼成 `linux-image-amd64-amd64` | `--linux-packages "linux-image" --linux-flavours "amd64"` |
| 6 | security 源旧式 `bookworm/updates` 无 Release | `--security false` |

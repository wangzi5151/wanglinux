#!/bin/bash
# ============================================================================
#  WangLinux 仓库构建入口（兼容旧路径）
#  真正的构建逻辑在 pkgsrc/build-repo.sh（单一来源，避免两份脚本各自漂移）。
#  用法不变：sudo bash build-repo.sh
#  环境变量 SRC / OUT / SIGN / REPO_URL / GNUPGHOME 照常生效。
# ============================================================================
set -Eeuo pipefail
exec bash "$(cd "$(dirname "$0")" && pwd)/pkgsrc/build-repo.sh" "$@"

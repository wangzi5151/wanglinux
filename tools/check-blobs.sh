#!/bin/bash
# ============================================================================
#  防 base64 blob 回归检测
#  背景：本仓库历史上几乎所有文本文件（脚本、文档、配置）都被整份 base64
#  编码后提交，GitHub 上无法阅读也无法直接运行。本脚本确保这类文件不再出现。
#  规则：git 跟踪的文本文件若为单行且能被 base64 -d 成功解码为合法 UTF-8，
#        即判定为 blob，退出码 1 使 CI 失败。
# ============================================================================
set -uo pipefail
fail=0
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  # 跳过二进制文件（按内容判断，不看扩展名）
  LC_ALL=C grep -qI . "$f" 2>/dev/null || continue
  [ "$(wc -l < "$f")" -le 1 ] || continue
  if base64 -d "$f" 2>/dev/null | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1; then
    echo "✘ 检测到 base64 blob（应提交明文）: $f"
    fail=1
  fi
done < <(git ls-files -z 2>/dev/null)
if [ "$fail" -eq 0 ]; then
  echo "✔ 未发现 base64 blob，跟踪的文本文件全部可读"
fi
exit $fail

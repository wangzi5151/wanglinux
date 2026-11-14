#!/bin/bash
# ============================================================================
#  构建 WangLinux "aurora" 软件仓库（在 chroot 内以 root 运行）
#  产出：/srv/wanglinux-repo/ —— 可直接 file: 或 http:// 供给 apt 的仓库
# ============================================================================
set -Eeuo pipefail
export LC_ALL=C.UTF-8

SRC="${SRC:-/srv/repo-src}"
OUT="${OUT:-/srv/wanglinux-repo}"
SUITE="aurora"
CODENAME="aurora"
COMP="main"
ARCHES="amd64 arm64 all"
REPO_URL="${REPO_URL:-https://wanglinux.github.io/wanglinux-archive}"
PKGS="wanglinux-base wanglinux-theme wanglinux-desktop wanglinux-tools wanglinux-server wanglinux-devel"
SIGN="${SIGN:-yes}"

log() { printf '\033[1;35m[repo]\033[0m %s\n' "$*"; }

# ---------------------------------------------------------------- 壁纸 ----
log "生成壁纸 aurora.png (1920x1080)"
python3 - <<'PY'
import zlib, struct, math
W, H = 1920, 1080
rows = bytearray()
for y in range(H):
    t = y / H
    r = int(16 + 70 * t)
    g = int(6 + 18 * math.sin(t * 3.14))
    b = int(38 + 150 * t * t)
    px = bytes((r, g, b))
    row = bytearray()
    for x in range(0, W):
        f = 1.0
        # 中间一道"极光"渐带
        d = abs(x / W - 0.5)
        if d < 0.34:
            f = 1.0 + (0.34 - d) * 1.9 * (0.35 + 0.65 * math.sin((t + x / W) * 2.6))
        rr = min(255, int(r * f))
        gg = min(255, int(g * f))
        bb = min(255, int(b * f * 1.05))
        row += bytes((rr, gg, bb))
    rows.append(0)
    rows += row
def chunk(tag, data):
    return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
png = (b'\x89PNG\r\n\x1a\n'
       + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(bytes(rows), 6))
       + chunk(b'IEND', b''))
open('/srv/repo-src/wanglinux-theme/usr/share/wallpapers/wanglinux/aurora.png', 'wb').write(png)
print('  -> %d bytes' % len(png))
PY

# ------------------------------------------------------------- 编译 .deb ----
log "编译软件包"
rm -rf "$OUT"; mkdir -p "$OUT/pool/main"
for p in $PKGS; do
  d="$SRC/$p"
  [ -d "$d" ] || { echo "缺少 $d"; exit 1; }
  find "$d" -type d -exec chmod 755 {} +
  find "$d" -type f ! -path "$d/DEBIAN/*" -exec chmod 644 {} +
  for b in usr/bin usr/sbin usr/games; do [ -d "$d/$b" ] && find "$d/$b" -type f -exec chmod 755 {} +; done
  for s in postinst preinst prerm postrm config; do
    [ -f "$d/DEBIAN/$s" ] && chmod 755 "$d/DEBIAN/$s"
  done
  v=$(sed -n 's/^Version: //p' "$d/DEBIAN/control" | head -1)
  mkdir -p "$OUT/pool/main/${p:0:4}/$p"
  dpkg-deb --build --root-owner-group "$d" "$OUT/pool/main/${p:0:4}/$p/${p}_${v}_all.deb" >/dev/null
  printf '  %-22s %s  %s\n' "$p" "$v" "$(du -h "$OUT/pool/main/${p:0:4}/$p/${p}_${v}_all.deb" | cut -f1)"
done

# --------------------------------------------------------- Packages 索引 ----
log "生成 Packages 索引"
mkdir -p "$OUT/dists/$SUITE/$COMP"
: > "$OUT/.Packages"
for deb in $(find "$OUT/pool" -name '*.deb' | sort); do
  rel=${deb#"$OUT"/}
  dpkg-deb -f "$deb" Package Version Architecture Maintainer Depends Suggests Section Priority Description \
    | sed '/^[A-Za-z-]*:$/d' >> "$OUT/.Packages"
  {
    echo "Filename: $rel"
    echo "Size: $(stat -c%s "$deb")"
    echo "MD5sum: $(md5sum "$deb" | cut -d' ' -f1)"
    echo "SHA1: $(sha1sum "$deb" | cut -d' ' -f1)"
    echo "SHA256: $(sha256sum "$deb" | cut -d' ' -f1)"
    echo
  } >> "$OUT/.Packages"
done
for a in all amd64 arm64; do
  mkdir -p "$OUT/dists/$SUITE/$COMP/binary-$a"
  cp "$OUT/.Packages" "$OUT/dists/$SUITE/$COMP/binary-$a/Packages"
  gzip -9 -n -k -f "$OUT/dists/$SUITE/$COMP/binary-$a/Packages"
done
rm -f "$OUT/.Packages"

# ------------------------------------------------------------ Release 文件 ----
log "生成 Release（含校验和）"
{
  echo "Origin: WangLinux"
  echo "Label: WangLinux"
  echo "Suite: $SUITE"
  echo "Codename: $CODENAME"
  echo "Version: 1.0"
  echo "Architectures: $ARCHES"
  echo "Components: $COMP"
  echo "Description: WangLinux 1.0 (Aurora) - Debian 12 based distribution"
  echo "Date: $(date -Ru)"
  echo "Valid-Until: $(date -Ru -d '+30 days')"
  cd "$OUT/dists/$SUITE"
  for h in MD5Sum SHA1 SHA256; do
    case $h in MD5Sum) cmd=md5sum;; SHA1) cmd=sha1sum;; SHA256) cmd=sha256sum;; esac
    echo "$h:"
    find main -name 'Packages' -o -name 'Packages.gz' | sort | while read -r f; do
      printf ' %s %16s %s\n' "$($cmd "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
    done
  done
} > "$OUT/dists/$SUITE/Release"

# --------------------------------------------------------------- 签名 ----
if [ "$SIGN" = yes ] && command -v gpg >/dev/null 2>&1; then
  log "生成/复用签名密钥并签名 InRelease"
  export GNUPGHOME="${GNUPGHOME:-/srv/wanglinux-gnupg}"; mkdir -p "$GNUPGHOME"; chmod 700 "$GNUPGHOME"
  if ! gpg --list-secret-keys wanglinux@local >/dev/null 2>&1; then
    gpg --batch --pinentry-mode loopback --passphrase '' \
        --quick-generate-key "WangLinux Archive Signing Key <archive@wanglinux.local>" rsa3072 sign never >/dev/null 2>&1 \
      || echo "  (密钥生成失败，仓库将以 trusted=yes 方式使用)"
  fi
  KEYID=$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec:/{print $5; exit}')
  if [ -n "${KEYID:-}" ]; then
    gpg --batch --yes --pinentry-mode loopback --passphrase '' --clearsign \
        -o "$OUT/dists/$SUITE/InRelease" "$OUT/dists/$SUITE/Release"
    gpg --batch --yes --pinentry-mode loopback --passphrase '' --armor --detach-sign \
        -o "$OUT/dists/$SUITE/Release.gpg" "$OUT/dists/$SUITE/Release"
    gpg --batch --yes --export "$KEYID" > "$OUT/wanglinux-archive-keyring.gpg"
    echo "  签名完成: $KEYID"
  fi
fi

# ------------------------------------------------------------ 使用说明 ----
cat > "$OUT/README.txt" <<EOF
WangLinux "aurora" 软件仓库
=================================
套件: $SUITE   组件: $COMP   架构: $ARCHES
包含: $PKGS
URL : $REPO_URL

安装方式一（已导入公钥）:
  sudo cp wanglinux-archive-keyring.gpg /usr/share/keyrings/
  echo "deb [signed-by=/usr/share/keyrings/wanglinux-archive-keyring.gpg] $REPO_URL $SUITE $COMP" \\
    | sudo tee /etc/apt/sources.list.d/wanglinux.list
  sudo apt update && sudo apt install wanglinux-desktop

安装方式二（本地路径 / 未签名时）:
  echo "deb [trusted=yes] file:/srv/wanglinux-repo $SUITE $COMP" \\
    | sudo tee /etc/apt/sources.list.d/wanglinux.list
EOF

log "仓库构建完成"
du -sh "$OUT"; find "$OUT/pool" -name '*.deb' | sed 's|^|  |'

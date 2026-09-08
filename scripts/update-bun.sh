#!/usr/bin/env bash
# 更新 pkgs/bun/package.nix 到 oven-sh/bun 最新 release
# 用法: ./scripts/update-bun.sh [--check]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/pkgs/bun/package.nix"

current_version="$(grep -oP 'version = "\K[^"]+' "$PKG" | head -n1)"
echo "当前版本: $current_version"

latest_tag="$(gh api repos/oven-sh/bun/releases/latest --jq '.tag_name')"
latest_version="${latest_tag#bun-v}"
echo "上游最新: $latest_version ($latest_tag)"

if [[ "$latest_version" == "$current_version" ]]; then
  echo "已是最新，无需更新。"
  exit 0
fi

if [[ "${1:-}" == "--check" ]]; then
  echo "发现新版 $latest_version，可运行 ./scripts/update-bun.sh 更新。"
  exit 0
fi

echo "更新 $current_version -> $latest_version ..."

declare -A files=(
  ["aarch64-darwin"]="bun-darwin-aarch64.zip"
  ["aarch64-linux"]="bun-linux-aarch64.zip"
  ["x86_64-darwin"]="bun-darwin-x64.zip"
  ["x86_64-linux"]="bun-linux-x64-baseline.zip"
)

# 预取各平台 hash
declare -A hashes=()
for platform in "${!files[@]}"; do
  file="${files[$platform]}"
  url="https://github.com/oven-sh/bun/releases/download/bun-v${latest_version}/${file}"
  echo "  预取 $platform <- $url"
  h="$(nix store prefetch-file --json "$url" | jq -r .hash)"
  hashes["$platform"]="$h"
  echo "    $h"
done

# 用 python 做精确替换，避免 bash/perl 转义坑
python3 - "$PKG" "$latest_version" "${hashes["aarch64-darwin"]}" "${hashes["aarch64-linux"]}" "${hashes["x86_64-darwin"]}" "${hashes["x86_64-linux"]}" << 'PY'
import sys, re
pkg, ver, h_ad, h_al, h_xd, h_xl = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6]
hashes = {
    "aarch64-darwin": h_ad,
    "aarch64-linux": h_al,
    "x86_64-darwin": h_xd,
    "x86_64-linux": h_xl,
}
text = open(pkg).read()
# 1) version
text = re.sub(r'version = "[^"]+";', f'version = "{ver}";', text, count=1)
# 2) 逐平台 hash：定位 "platform" = fetchurl { ... hash = "sha256-..." }
for plat, h in hashes.items():
    # 注意用 .*? 而非 [^}]*?：url 里的 ${finalAttrs.version} 含 '}' 会截断匹配
    pat = re.compile(r'("' + re.escape(plat) + r'"\s*=\s*fetchurl\s*\{.*?hash\s*=\s*")sha256-[^"]+', re.DOTALL)
    text, n = pat.subn(r'\g<1>' + h, text)
    if n == 0:
        sys.exit(f"ERROR: 未匹配到 {plat} 的 hash 块")
open(pkg, "w").write(text)
PY

echo "已更新到 $latest_version："
grep -E 'version =|hash = ' "$PKG" | head -n 10
echo ""
echo "建议运行: nix build .#bun  验证构建"

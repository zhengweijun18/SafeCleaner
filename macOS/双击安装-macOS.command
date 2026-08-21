#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SafeMac Cleaner Lite"
DIST="$ROOT/dist"

"$ROOT/构建-macOS.command"

APP="$(find "$DIST" -maxdepth 1 -type d -name 'SafeMacCleaner-v4.14-macOS-*.app' | head -1)"
if [[ -z "$APP" ]]; then
  echo "❌ 未找到构建结果"
  exit 1
fi

TARGET="/Applications/$APP_NAME.app"

echo
echo "③ 安装到 /Applications"

if [[ -w "/Applications" ]]; then
  rm -rf "$TARGET"
  /usr/bin/ditto "$APP" "$TARGET"
else
  /usr/bin/osascript <<OSA
do shell script "/bin/rm -rf '/Applications/$APP_NAME.app' && /usr/bin/ditto '$APP' '/Applications/$APP_NAME.app'" with administrator privileges
OSA
fi

# 仅处理本机刚构建出来的 App，不改变 Gatekeeper 全局策略。
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true

echo
echo "✅ 已安装：$TARGET"
echo "正在启动……"
open "$TARGET"

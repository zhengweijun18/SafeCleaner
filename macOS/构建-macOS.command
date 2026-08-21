#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="SafeMac Cleaner Lite"
EXECUTABLE="SafeMacCleanerLite"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_MAJOR="${SDK_VERSION%%.*}"
HOST_ARCH="$(uname -m)"

DIST="$ROOT/dist"
WORK="$ROOT/.build-v414"
APP="$WORK/$APP_NAME.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

clear
echo "╔════════════════════════════════════════════╗"
echo "║ SafeMac Cleaner Lite v4.14 · macOS 构建   ║"
echo "╚════════════════════════════════════════════╝"
echo
echo "SDK:   macOS $SDK_VERSION"
echo "本机:  $HOST_ARCH"
echo

rm -rf "$WORK"
mkdir -p "$MACOS" "$RESOURCES" "$DIST"

compile_arch() {
  local arch="$1"
  local minver="$2"
  local out="$3"
  local target="${arch}-apple-macosx${minver}"

  echo "  编译 $arch · 最低 macOS $minver"
  xcrun swiftc \
    -swift-version 5 \
    -O \
    -target "$target" \
    -sdk "$SDK" \
    -framework AppKit \
    -framework Foundation \
    -framework QuartzCore \
    "$ROOT"/LegacySources/*.swift \
    -o "$out"
}

BUILD_KIND=""

if [[ "$SDK_MAJOR" -ge 11 ]]; then
  echo "① 构建 Universal2（Intel + Apple Silicon）"
  compile_arch "x86_64" "10.15" "$WORK/app-x86_64"
  compile_arch "arm64" "11.0" "$WORK/app-arm64"
  xcrun lipo -create \
    "$WORK/app-x86_64" \
    "$WORK/app-arm64" \
    -output "$MACOS/$EXECUTABLE"
  BUILD_KIND="Universal2"
else
  echo "① 当前 SDK 不支持 Apple Silicon，构建 Intel 兼容版"
  if [[ "$HOST_ARCH" != "x86_64" ]]; then
    echo "❌ 当前 SDK 过旧且本机不是 Intel，无法构建。"
    exit 1
  fi
  compile_arch "x86_64" "10.15" "$MACOS/$EXECUTABLE"
  BUILD_KIND="Intel"
fi

cp "$ROOT/Info.plist" "$CONTENTS/Info.plist"

if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1 && [[ -f "$ROOT/Resources/AppIcon.png" ]]; then
  ICONSET="$WORK/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  sips -z 16 16     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64     "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
fi

echo "② 代码签名"
SIGN_IDENTITY="$(
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -nE 's/.*"([^"]+)".*/\1/p' \
    | grep -E 'Developer ID Application|Apple Development|Mac Developer' \
    | head -1 || true
)"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "  使用：$SIGN_IDENTITY"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"
else
  echo "  未找到稳定证书，使用本机临时签名"
  codesign --force --deep --sign - "$APP"
fi

OUT="$DIST/SafeMacCleaner-v4.14-macOS-${BUILD_KIND}.app"
rm -rf "$OUT"
/usr/bin/ditto "$APP" "$OUT"

echo
echo "✅ 构建完成："
echo "   $OUT"
echo
echo "架构：$(xcrun lipo -archs "$OUT/Contents/MacOS/$EXECUTABLE" 2>/dev/null || echo "$HOST_ARCH")"

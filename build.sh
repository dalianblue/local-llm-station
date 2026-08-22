#!/bin/bash
# 重新编译 QwenServer.app（无需 Xcode）
set -e
cd "$(dirname "$0")"

APP=QwenServer.app
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources

# Info.plist（每次重写，含图标注册）
cat > $APP/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>QwenServer</string>
    <key>CFBundleDisplayName</key><string>Qwen 服务控制</string>
    <key>CFBundleIdentifier</key><string>local.llmstation.server</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>QwenServer</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# 从 assets/logo.png 生成 .icns（存在时）
if [ -f assets/logo.png ]; then
    ICONSET=$APP/Contents/Resources/QwenServer.iconset
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size assets/logo.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size*2)) $((size*2)) assets/logo.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    sips -z 1024 1024 assets/logo.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o $APP/Contents/Resources/QwenServer.icns
    rm -rf "$ICONSET"
fi

# 菜单栏托盘图标（存在时复制进 Resources，TrayLabel 运行时加载）
[ -f assets/qwen.png ] && cp assets/qwen.png $APP/Contents/Resources/qwen.png

swiftc -O -parse-as-library -o $APP/Contents/MacOS/QwenServer QwenServer.swift
touch $APP
echo "构建完成: $APP"

# 如果 /Applications 里有副本，同步更新（二进制+资源）
if [ -d /Applications/$APP ]; then
    mkdir -p /Applications/$APP/Contents/Resources
    cp $APP/Contents/MacOS/QwenServer /Applications/$APP/Contents/MacOS/QwenServer
    cp $APP/Contents/Info.plist /Applications/$APP/Contents/Info.plist
    cp -R $APP/Contents/Resources/. /Applications/$APP/Contents/Resources/
    touch /Applications/$APP
    echo "已同步到 /Applications/$APP（需重启 app 生效）"
fi

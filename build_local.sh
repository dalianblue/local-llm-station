#!/bin/bash
# 重新编译 LocalLLMServer.app（Ollama 后端，无需 Xcode）
set -e
cd "$(dirname "$0")"

APP=LocalLLMServer.app
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources

# Info.plist（每次重写，含图标注册）
cat > $APP/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>LocalLLMServer</string>
    <key>CFBundleDisplayName</key><string>LocalLLM 服务控制</string>
    <key>CFBundleIdentifier</key><string>local.llmstation.server.ollama</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>LocalLLMServer</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# 从 assets/ollama.png 生成 .icns（存在时）
if [ -f assets/ollama.png ]; then
    ICONSET=$APP/Contents/Resources/LocalLLMServer.iconset
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size assets/ollama.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size*2)) $((size*2)) assets/ollama.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    sips -z 1024 1024 assets/ollama.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o $APP/Contents/Resources/LocalLLMServer.icns
    rm -rf "$ICONSET"
fi

# 菜单栏托盘图标（存在时复制进 Resources，TrayLabel 运行时加载）
[ -f assets/tray.png ] && cp assets/tray.png $APP/Contents/Resources/tray.png

swiftc -O -parse-as-library -o $APP/Contents/MacOS/LocalLLMServer LocalLLMServer.swift
touch $APP
echo "构建完成: $APP"

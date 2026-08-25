#!/bin/bash
# 重新编译 LocalLLMServer-oMLX.app（oMLX 后端，无需 Xcode）
# 同一份 LocalLLMServer.swift 源码，-D OMLX 切换后端分支；Ollama 版由 build_local.sh 产出
set -e
cd "$(dirname "$0")"

APP=LocalLLMServer-oMLX.app
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources

# Info.plist（每次重写，含图标注册）
cat > $APP/Contents/Info.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>LocalLLMServer-oMLX</string>
    <key>CFBundleDisplayName</key><string>LocalLLM 服务控制（oMLX）</string>
    <key>CFBundleIdentifier</key><string>local.llmstation.server.omlx</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>LocalLLMServer</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# 从 assets/omlx.png 生成 .icns（存在时）
if [ -f assets/omlx.png ]; then
    ICONSET=$APP/Contents/Resources/LocalLLMServer.iconset
    rm -rf "$ICONSET"; mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size assets/omlx.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        sips -z $((size*2)) $((size*2)) assets/omlx.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    sips -z 1024 1024 assets/omlx.png --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o $APP/Contents/Resources/LocalLLMServer.icns
    rm -rf "$ICONSET"
fi

# 菜单栏托盘图标（矢量 template，存在时复制进 Resources，TrayIcon 运行时加载）
[ -f assets/iconTemplate.pdf ] && cp assets/iconTemplate.pdf $APP/Contents/Resources/iconTemplate.pdf

swiftc -O -parse-as-library -D OMLX -o $APP/Contents/MacOS/LocalLLMServer-oMLX LocalLLMServer.swift
touch $APP
echo "构建完成: $APP"

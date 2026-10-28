#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"
SDK="$PWD/.sdk"
RES="$PWD/.toolchain/usr/lib/swift"

mkdir -p build

PRODUCT_NAME="Feihete"
VERSION="0.1.1"
BUILD_NUMBER="2"
APP="build/${PRODUCT_NAME}.app"
DMG="build/${PRODUCT_NAME}.dmg"
TOTAL_STEPS=7
DONE_STEPS=0

run_step() {
    local label="$1"
    shift
    local log
    local pid
    local spinner='|/-\\'
    local tick=0
    local status

    log=$(mktemp "${TMPDIR:-/tmp}/feihete-build.XXXXXX")
    "$@" >"$log" 2>&1 &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r[%3d%%] %-30s [%s]" "$((DONE_STEPS * 100 / TOTAL_STEPS))" "$label" "${spinner:tick % 4:1}"
        tick=$((tick + 1))
        sleep 0.15
    done

    if wait "$pid"; then
        DONE_STEPS=$((DONE_STEPS + 1))
        printf "\r[%3d%%] %-30s [✓]\n" "$((DONE_STEPS * 100 / TOTAL_STEPS))" "$label"
        rm -f "$log"
    else
        status=$?
        printf "\r[%3d%%] %-30s [✗]\n" "$((DONE_STEPS * 100 / TOTAL_STEPS))" "$label"
        cat "$log"
        rm -f "$log"
        return "$status"
    fi
}

prepare_toolchain() {
    if [ ! -d "$SDK/usr/include" ]; then
        echo "bootstrap: creating patched SDK symlink tree"
        rm -rf "$SDK"
        cp -Rs "$(readlink -f /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)" "$SDK"
        NEW="// swift-compiler-version: $(swift --version 2>/dev/null | grep -o 'Apple Swift version [^)]*)' | head -1 || true)"
        NEW="// swift-compiler-version: $(swift --version 2>/dev/null | tail -1 | sed 's/^Apple Swift version/Apple Swift version/')"
        CUR="$(swift --version 2>/dev/null | tail -1)"
        NEW="// swift-compiler-version: $CUR"
        for p in $(find "$SDK" \( -name "x86_64-apple-macos.swiftinterface" -o -name "x86_64-apple-macos.private.swiftinterface" -o -name "arm64-apple-macos.swiftinterface" -o -name "arm64-apple-macos.private.swiftinterface" \) -type l); do
            src=$(readlink -f "$p")
            if [ -f "$src" ]; then
                sed "s|// swift-compiler-version:.*|$NEW|" "$src" > "$p.part" && mv "$p.part" "$p" || true
            fi
        done
        rm -rf "$SDK/usr/include/swift"
    fi

    if [ ! -d "$RES/clang" ] || [ ! -f "$PWD/.toolchain/usr/include/swift/bridging.modulemap" ]; then
        echo "bootstrap: creating clean toolchain resource copy"
        T="$PWD/.toolchain"
        rm -rf "$T"
        mkdir -p "$T/usr/lib/swift" "$T/usr/include/swift" "$T/usr/lib/clang"
        (cd /Library/Developer/CommandLineTools/usr/lib/swift && tar cf - .) | (cd "$T/usr/lib/swift" && tar xf -)
        CLANGDIR=$(readlink -f /Library/Developer/CommandLineTools/usr/lib/swift/clang)
        ln -sfn "$CLANGDIR" "$T/usr/lib/clang/16"
        ln -sf /Library/Developer/CommandLineTools/usr/include/swift/bridging "$T/usr/include/swift/bridging"
        ln -sf /Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap "$T/usr/include/swift/bridging.modulemap"
    fi
}

build_app() {
    swiftc -parse-as-library \
        -resource-dir "$RES" -sdk "$SDK" \
        -O -target "$TARGET" \
        $(find Sources/FeiheteCore Sources/Feihete -name "*.swift") \
        -o "build/${PRODUCT_NAME}"
}

build_cli() {
    swiftc \
        -resource-dir "$RES" -sdk "$SDK" \
        -O -target "$TARGET" \
        Sources/FeiheteCore/*.swift Sources/taptool/main.swift \
        -o build/taptool
}

assemble_app() {
    rm -rf "$APP"
    mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
    cp "build/${PRODUCT_NAME}" "$APP/Contents/MacOS/${PRODUCT_NAME}"
    cp Feihete.svg "$APP/Contents/Resources/Feihete.svg"
    if [ -f AppIcon.icns ]; then
        cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    fi

    cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Feihete</string>
    <key>CFBundleIdentifier</key>
    <string>com.feihete.app</string>
    <key>CFBundleName</key>
    <string>Feihete</string>
    <key>CFBundleDisplayName</key>
    <string>Feihete</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF
}

sign_app() {
    codesign --force --sign - "$APP" 2>/dev/null || true
}

package_artifacts() {
    local stage="build/dmg-stage"
    local rw="build/${PRODUCT_NAME}-rw.dmg"
    local mnt="build/.dmg-mount"
    local zip="build/${PRODUCT_NAME}.zip"

    rm -rf "$stage" "$rw" "$mnt" "$DMG" "$zip"
    mkdir -p "$stage"
    cp -R "$APP" "$stage/"
    # 关键：放一个指向 /Applications 的快捷方式，用户拖进去就完成安装
    ln -s /Applications "$stage/Applications"
    if [ -f AppIcon.icns ]; then
        cp AppIcon.icns "$stage/.VolumeIcon.icns"
    fi

    if hdiutil create -volname "$PRODUCT_NAME" -srcfolder "$stage" -ov -format UDRW -fs HFS+ "$rw" >/dev/null 2>&1; then
        mkdir -p "$mnt"
        if hdiutil attach "$rw" -nobrowse -readwrite -noautoopen -mountpoint "$mnt" >/dev/null 2>&1; then
            # 给卷设置自定义图标
            SetFile -a C "$mnt" 2>/dev/null || true
            hdiutil detach "$mnt" -quiet >/dev/null 2>&1 || hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
            hdiutil convert "$rw" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null 2>&1 && rm -f "$rw"
        fi
    fi

    if [ -f "$DMG" ]; then
        echo "Built $DMG"
    else
        rm -f "$rw"
        ditto -c -k --sequesterRsrc --keepParent "$APP" "$zip"
        echo "DMG 创建不可用，已生成 $zip"
    fi
}

verify_package() {
    local mnt="build/.verify-mount"
    rm -rf "$mnt"
    mkdir -p "$mnt"
    if ! hdiutil attach "$DMG" -nobrowse -readonly -noautoopen -mountpoint "$mnt" >/dev/null 2>&1; then
        echo "✗ 无法挂载 $DMG"
        return 1
    fi

    local bad=0
    [ -d "$mnt/${PRODUCT_NAME}.app" ] || { echo "✗ 缺少 ${PRODUCT_NAME}.app"; bad=1; }
    [ -L "$mnt/Applications" ] || { echo "✗ 缺少 Applications 快捷方式（用户无法拖拽安装）"; bad=1; }
    [ -f "$mnt/${PRODUCT_NAME}.app/Contents/Resources/AppIcon.icns" ] || { echo "✗ 缺少应用图标"; bad=1; }
    if ! /usr/bin/plutil -lint "$mnt/${PRODUCT_NAME}.app/Contents/Info.plist" >/dev/null 2>&1; then
        echo "✗ Info.plist 不是合法 plist"
        bad=1
    fi
    /usr/bin/plutil -p "$mnt/${PRODUCT_NAME}.app/Contents/Info.plist" 2>/dev/null | grep -q "CFBundleIconFile" \
        || { echo "✗ Info.plist 未声明 CFBundleIconFile"; bad=1; }

    hdiutil detach "$mnt" -quiet >/dev/null 2>&1 || hdiutil detach "$mnt" -force >/dev/null 2>&1 || true
    rm -rf "$mnt"

    if [ "$bad" -eq 0 ]; then
        echo "校验通过：app + Applications 快捷方式 + 图标齐全，版本 ${VERSION}"
    fi
    return "$bad"
}

run_step "准备 Swift 工具链" prepare_toolchain
run_step "编译 Feihete 应用" build_app
run_step "编译 taptool 命令行工具" build_cli
run_step "组装应用包" assemble_app
run_step "签名应用包" sign_app
run_step "生成 DMG 安装包" package_artifacts
run_step "校验安装包" verify_package

echo "构建完成：${APP}，版本 ${VERSION}"

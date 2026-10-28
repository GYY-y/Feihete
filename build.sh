#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"
SDK="$PWD/.sdk"
RES="$PWD/.toolchain/usr/lib/swift"

mkdir -p build

PRODUCT_NAME="Feihete"
APP="build/${PRODUCT_NAME}.app"
DMG="build/${PRODUCT_NAME}.dmg"
TOTAL_STEPS=6
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

    cat > "$APP/Contents/Info.plist" <<'EOF'
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
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
    if hdiutil create \
            -volname "$PRODUCT_NAME" \
            -srcfolder "$APP" \
            -ov \
            -format UDZO \
            "$DMG" >/dev/null; then
        echo "Built $DMG"
    else
        rm -f "$DMG"
        ZIP="build/${PRODUCT_NAME}.zip"
        ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
        echo "DMG creation unavailable; built $ZIP instead"
    fi
}

run_step "准备 Swift 工具链" prepare_toolchain
run_step "编译 Feihete 应用" build_app
run_step "编译 taptool 命令行工具" build_cli
run_step "组装应用包" assemble_app
run_step "签名应用包" sign_app
run_step "生成 DMG 安装包" package_artifacts

echo "构建完成：$APP"

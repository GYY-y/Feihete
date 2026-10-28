#!/bin/bash
# 重新生成 AppIcon.icns（仅在修改 Feihete.svg 后需要执行）
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH=$(uname -m)
TARGET="${ARCH}-apple-macos13.0"

swiftc -O -target "$TARGET" \
    -resource-dir "$PWD/.toolchain/usr/lib/swift" \
    -sdk "$PWD/.sdk" \
    tools/make-icon.swift \
    -o build/make-icon

./build/make-icon
rm -f build/make-icon

#!/bin/bash
# =============================================================================
# eMP-toolchain 一键解压脚本
#
# 用法：
#   ./setup.sh
#   然后按提示 export T113_SDK 与 STAGING_DIR
# =============================================================================
set -e
cd "$(dirname "$0")"

echo "=== eMP-toolchain setup ==="

if [ -d toolchain ] && [ -d sysroot ]; then
    echo "[skip] toolchain/ 与 sysroot/ 已存在，无需解压"
else
    if [ -f tc_toolchain.tar.gz ]; then
        echo "[extract] toolchain ..."
        tar xzf tc_toolchain.tar.gz
    else
        echo "[error] 缺少 tc_toolchain.tar.gz"
        exit 1
    fi

    if [ -f tc_sysroot.tar.gz ]; then
        echo "[extract] sysroot ..."
        tar xzf tc_sysroot.tar.gz
    else
        echo "[error] 缺少 tc_sysroot.tar.gz"
        exit 1
    fi
fi

echo ""
echo "=== 验证工具链 ==="
TOOLCHAIN_BIN="$(pwd)/toolchain/bin"
if [ -x "$TOOLCHAIN_BIN/arm-openwrt-linux-gcc" ]; then
    echo "OK: $TOOLCHAIN_BIN/arm-openwrt-linux-gcc"
else
    echo "[error] 工具链可执行文件缺失"
    exit 1
fi

echo ""
echo "=== 使用方式（复制以下三行到 shell 或写入 ~/.bashrc） ==="
echo "export T113_SDK=\"$(pwd)\""
echo "export STAGING_DIR=\"\$(T113_SDK)/sysroot\""
echo ""
echo "然后到你的项目里："
echo "  Makefile 方式:  make CROSS=1 -j32"
echo "  CMake 方式:     cmake -DCMAKE_TOOLCHAIN_FILE=cmake/build_for_t113s3.cmake -DT113_SDK=\$T113_SDK .."

#
# cross compile env define (Allwinner T113-S3)
#
# 本文件随 eMP-toolchain 仓库分发，是通用的 T113-S3 交叉编译工具链文件，
# 任何 eMP 系列项目均可直接引用，无需拷贝。
#
# 工具链路径解析优先级：
#   1. cmake 命令行  -DT113_SDK=<工具链仓库根>（推荐）
#   2. 环境变量      export T113_SDK=<工具链仓库根>
#   3. 回退          本机 tina-sdk 的默认绝对路径
#
# 工具链仓库（含编译器 + sysroot，可独立拉取）：
#   https://github.com/ZhangKeLiang0627/eMP-toolchain
#
# 用法示例（在任意项目目录下）：
#   export T113_SDK=/path/to/eMP-toolchain
#   export STAGING_DIR=$T113_SDK/sysroot
#   cmake -DCMAKE_TOOLCHAIN_FILE=<eMP-toolchain路径>/cmake/build_for_t113s3.cmake \
#         -DT113_SDK=$T113_SDK ..
#   make -j32
#

SET(CMAKE_SYSTEM_NAME Linux)
# 配置库的安装路径
SET(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install)

SET(CMAKE_SYSTEM_PROCESSOR "arm")
SET(CMAKE_HOST_SYSTEM_PROCESSOR "arm")

# ---- 工具链 / sysroot 路径解析 ----
if(NOT DEFINED T113_SDK)
    set(T113_SDK $ENV{T113_SDK})
endif()

if(T113_SDK)
    set(TOOLCHAIN_DIR "${T113_SDK}/toolchain/bin/")
    set(SYSROOT_DIR  "${T113_SDK}/sysroot")
    set(FREETYPE_INC "${SYSROOT_DIR}/usr/include/freetype2")
else()
    set(TOOLCHAIN_DIR "/home/hugokkl/tina-sdk/prebuilt/gcc/linux-x86/arm/toolchain-sunxi-musl/toolchain/bin/")
    set(SYSROOT_DIR  "/home/hugokkl/tina-sdk/out/t113-pi/staging_dir/target")
    set(FREETYPE_INC "/home/hugokkl/tina-sdk/out/t113-pi/compile_dir/target/freetype-2.13.2/include")
endif()

message(STATUS "T113 toolchain dir : ${TOOLCHAIN_DIR}")
message(STATUS "T113 sysroot dir   : ${SYSROOT_DIR}")

# 设置头文件所在目录
include_directories(
    ${SYSROOT_DIR}/usr/include
    ${SYSROOT_DIR}/usr/include/allwinner
    ${SYSROOT_DIR}/usr/include/allwinner/include
    ${FREETYPE_INC}
)

set(CMAKE_PREFIX_PATH /usr)

# 设置第三方库所在位置
link_directories(
    ${SYSROOT_DIR}/lib
    ${SYSROOT_DIR}/usr/lib 
)

add_compile_options(
    -pipe 
    -march=armv7-a 
    -mtune=cortex-a7 
    -mfpu=neon 
    -mfloat-abi=hard 
    -fstack-protector
)

SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# allwinner t113s3
SET(CMAKE_C_COMPILER ${TOOLCHAIN_DIR}arm-openwrt-linux-gcc)
SET(CMAKE_CXX_COMPILER ${TOOLCHAIN_DIR}arm-openwrt-linux-g++)

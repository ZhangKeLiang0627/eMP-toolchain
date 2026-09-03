# eMP-toolchain

Allwinner T113-S3 (TinaLinux) 交叉编译工具链，含编译器与 sysroot 依赖库，独立于完整 tina-sdk。

从 `tina-sdk` 提取，供 eMP 系列项目（如 [easyMediaPlayer](https://github.com/ZhangKeLiang0627/EasyMediaPlayer)）在**没有完整 SDK 的机器**上直接做 T113-S3 交叉编译。

## 内容

| 组件 | 说明 |
|---|---|
| `tc_toolchain.tar.gz` (46M) | `arm-openwrt-linux-muslgnueabi` GCC 6.4.1 交叉编译器（解压出 `toolchain/`） |
| `tc_sysroot.tar.gz` (32M) | 板子头文件与库：`usr/include`（含 allwinner、freetype2）、`usr/lib`、`lib`（解压出 `sysroot/`） |
| `cmake/build_for_t113s3.cmake` | **通用 T113-S3 工具链文件**，任何项目可直接引用，无需拷贝 |

> 均 <100MB，满足 GitHub 单文件限制。解压后目录 ~230M。

## 快速开始

```bash
git clone https://github.com/ZhangKeLiang0627/eMP-toolchain
cd eMP-toolchain
./setup.sh                     # 解压出 toolchain/ 与 sysroot/ 并打印环境变量
```

然后按 setup.sh 输出设置环境变量（写进 `~/.bashrc` 更省事）：

```bash
export T113_SDK="/path/to/eMP-toolchain"
export STAGING_DIR="$T113_SDK/sysroot"
```

## 在项目中使用

### Makefile 方式（eMP-tokenMonitor 等）

```bash
cd your-project
export T113_SDK="/path/to/eMP-toolchain"
export STAGING_DIR="$T113_SDK/sysroot"
make CROSS=1 -j32
```

`Makefile` 已支持 `T113_SDK` 变量：设置后自动使用
`$T113_SDK/toolchain/bin/` 与 `$T113_SDK/sysroot`，未设置则回退到本机 tina-sdk 绝对路径。

### CMake 方式

```bash
cd your-project
export T113_SDK="/path/to/eMP-toolchain"
export STAGING_DIR="$T113_SDK/sysroot"
mkdir -p build && cd build
# 直接用本仓库自带的工具链文件（推荐，免拷贝）
cmake -DCMAKE_TOOLCHAIN_FILE=$T113_SDK/cmake/build_for_t113s3.cmake -DT113_SDK=$T113_SDK ..
make -j32
```

`build_for_t113s3.cmake` 路径解析优先级：`-DT113_SDK=` > 环境变量 `T113_SDK` > 本机 tina-sdk 默认绝对路径。
任何 eMP 系列项目都能引用 `$T113_SDK/cmake/build_for_t113s3.cmake`，无需把该文件拷贝进项目。

## 说明

- **GCC 6.4.1 / musl**：全志 T113-S3 TinaLinux 官方预编译工具链（`toolchain-sunxi-musl`）。
- **wrapper 机制**：`toolchain/bin/arm-openwrt-linux-gcc` 是 bash wrapper（含符号链接），
  必须保留在 Linux 下解压；`STAGING_DIR` 用于让 gcc 定位 sysroot 中的 libc 头文件与库。
- **依赖库**：sysroot 含 freetype / openssl(ssl,crypto) / zlib / bzip2 等
  eMP 系列常用的链接库（`.so`/`.a`），与板子 `/usr/lib` 一一对应。
- 本仓库只负责「编译产物生成」，运行库已内置在板子系统镜像中，无需额外部署。
- 如 tar.gz 被 Git LFS 或网速拖慢，也可直接从完整 tina-sdk 提取：
  ```bash
  # toolchain
  cp -a tina-sdk/prebuilt/gcc/linux-x86/arm/toolchain-sunxi-musl/toolchain .
  # sysroot（目标板依赖库）
  cp -a tina-sdk/out/t113-pi/staging_dir/target/{lib,usr/include,usr/lib} .
  # freetype 头文件（compile_dir，staging_dir 里没有）
  cp -a tina-sdk/out/t113-pi/compile_dir/target/freetype-*/include sysroot/usr/include/freetype2
  ```

# AGENTS.md — eMP-toolchain 维护指南

本文件供维护者（人类或 AI agent）理解 `eMP-toolchain` 的定位、制作与更新流程。
**每次改动/重新制作后，请回读本文件并同步更新其中的版本信息与步骤。**

## 1. 仓库定位

`eMP-toolchain` 是 Allwinner T113-S3（TinaLinux）的**独立交叉编译工具链**，
从完整 `tina-sdk` 中提取，让 eMP 系列项目在**没有完整 SDK 的机器**上也能交叉编译。

- 远端：`https://github.com/ZhangKeLiang0627/eMP-toolchain`（私有）
- 形态：`tar.gz` 分卷 + 一键解压脚本（`setup.sh`），用户在 Linux 上解压使用
- 为什么用 tar.gz 而非直接提交目录：工具链重度依赖 symlink（wrapper 链接），
  Windows 无法创建 symlink，必须由用户在 Linux 上 `tar xzf` 解压

## 2. 目录结构

```
eMP-toolchain/
├── README.md                       # 面向用户的使用说明
├── AGENTS.md                       # 本文件：面向维护者的制作/更新流程
├── setup.sh                        # 一键解压 toolchain/ 与 sysroot/，打印环境变量
├── cmake/build_for_t113s3.cmake    # 通用 T113-S3 工具链文件（项目免拷贝直接引用）
├── tc_toolchain.tar.gz             # ~46M：解压出 toolchain/（编译器）
└── tc_sysroot.tar.gz               # ~32M：解压出 sysroot/（板子头文件与库）
```

解压后：

```
toolchain/                          # GCC 6.4.1 musl 交叉编译器（toolchain-sunxi-musl）
├── bin/arm-openwrt-linux-gcc       # bash wrapper（符号链接链到 -muslgnueabi-*）
├── arm-openwrt-linux-muslgnueabi/  # 工具链内部 include/lib/sys-include
├── include/ lib/ libexec/ share/   # gcc 运行时
sysroot/                            # 精简的 staging_dir/target
├── lib/                            # 板子系统库（libawbase.so、libpam* 等）
└── usr/
    ├── include/                    # 全部头文件（含 allwinner/）
    │   └── freetype2/              # freetype 头文件（来自 compile_dir，见 §4.3）
    └── lib/                        # freetype/openssl/zlib/bzip2 等链接库
```

## 3. 依赖对象（谁在使用本仓库）

| 项目 | 仓库 | 依赖方式 |
|---|---|---|
| eMP-tokenMonitor | `ZhangKeLiang0627/eMP-tokenMonitor` | `export T113_SDK=<本仓库>` 后 `make CROSS=1` 或 `cmake -DCMAKE_TOOLCHAIN_FILE=$T113_SDK/cmake/build_for_t113s3.cmake` |
| 其他 eMP 系列（mainPage/settings/video 等，T113-S3 目标） | 私有 | 同一套 T113_SDK 机制 |

**sysroot 已包含的链接库**（对应板子 `/usr/lib`，eMP 项目常用）：

```
freetype2（libfreetype.so/.a + 头文件）
openssl（libssl.so、libcrypto.so）
zlib（libz.so）
bzip2（libbz2.so）
libstdc++（libstdc++.so.6）
```

> 若某项目需要新库（如 libcurl、libsqlite3），必须按 §5.2「新增依赖库」流程把库与头文件
> 加入 sysroot 并重新打包，否则交叉链接会报 undefined reference。

## 4. 制作办法（从 tina-sdk 重新提取）

### 4.1 前提

- 一台装有完整 `tina-sdk` 的 Linux 机器（本工作流示例：VM，`hugokkl` 用户）
- SDK 目录约定：`~/tina-sdk`（下文以 `/home/hugokkl/tina-sdk` 为例，按实际路径修改）
- **必须在本地磁盘操作**，不要放在 VMware 共享目录（`/mnt/share` 不支持 symlink）
- 需要 `sudo`（读 SDK 目录通常不需要，但保险）

### 4.2 提取工具链（toolchain/）

```bash
TC=/tmp/eMP-toolchain-build
mkdir -p $TC
# 复制编译器整树（cp -a 保留符号链接！）
cp -a /home/hugokkl/tina-sdk/prebuilt/gcc/linux-x86/arm/toolchain-sunxi-musl/toolchain $TC/toolchain
# 校验关键 wrapper 链接完好
ls -la $TC/toolchain/bin/arm-openwrt-linux-gcc   # 必须显示 -> arm-openwrt-linux-muslgnueabi-gcc
```

### 4.3 提取 sysroot（sysroot/）

```bash
SYSROOT_SRC=/home/hugokkl/tina-sdk/out/t113-pi/staging_dir/target
mkdir -p $TC/sysroot/usr
# 板子系统库目录（含 libawbase.so 等）
cp -a $SYSROOT_SRC/lib $TC/sysroot/lib
# 全部头文件（含 allwinner/ 子目录）
cp -a $SYSROOT_SRC/usr/include $TC/sysroot/usr/include
# 第三方链接库（.so/.a）
cp -a $SYSROOT_SRC/usr/lib $TC/sysroot/usr/lib

# ⚠️ freetype 头文件不在 staging_dir，在 compile_dir（漏了会找不到 ft2build.h）
FT_VERSION=$(ls -d /home/hugokkl/tina-sdk/out/t113-pi/compile_dir/target/freetype-* 2>/dev/null | head -1)
mkdir -p $TC/sysroot/usr/include/freetype2
cp -a $FT_VERSION/include/. $TC/sysroot/usr/include/freetype2/
```

### 4.4 打包

```bash
cd $TC
tar czf /tmp/tc_toolchain.tar.gz toolchain     # 预期 ~46M
tar czf /tmp/tc_sysroot.tar.gz   sysroot       # 预期 ~32M
ls -lh /tmp/tc_toolchain.tar.gz /tmp/tc_sysroot.tar.gz
```

**硬性约束**：每个 tar.gz 必须 < 100MB（GitHub 单文件限制）。如果超限：
- 裁剪 sysroot 里用不到的静态库（`usr/lib/*.a`）再打包
- 或对 sysroot 按库拆分多个包

### 4.5 验证（必做，否则不能发布）

```bash
# 1) 全新位置解压（模拟用户）
rm -rf /tmp/tc-test && mkdir -p /tmp/tc-test && cd /tmp/tc-test
tar xzf /tmp/tc_toolchain.tar.gz && tar xzf /tmp/tc_sysroot.tar.gz

# 2) 环境变量
export T113_SDK=/tmp/tc-test
export STAGING_DIR=$T113_SDK/sysroot

# 3) Makefile 方式验证
cd <某个 eMP 项目> && find . -name "*.o" -delete
make CROSS=1 -j8 && file eMP_tokenMonitor | grep -q "ELF 32-bit" && echo PASS

# 4) CMake 方式验证
mkdir -p build && cd build
cmake -DCMAKE_TOOLCHAIN_FILE=$T113_SDK/cmake/build_for_t113s3.cmake -DT113_SDK=$T113_SDK ..
make -j8 && file eMP_tokenMonitor | grep -q "ELF 32-bit" && echo PASS
```

## 5. 更新办法

### 5.1 场景 A：tina-sdk 升级（编译器/内核头/系统库版本变化）

1. 在装有新版 tina-sdk 的机器上按 §4 重新提取 + 打包（每次打包前 `rm -rf $TC` 清空）
2. 替换仓库根目录的 `tc_toolchain.tar.gz` / `tc_sysroot.tar.gz`
3. 按 §4.5 在两个目标项目上完整验证（Makefile + CMake）
4. 提交信息**必须注明新 SDK 版本与变更内容**，例如：
   ```
   Update toolchain: tina-sdk 2026.08 refresh
   - gcc 6.4.1 (unchanged) / sysroot rebuilt from out/t113-pi/staging_dir/target
   - bump: libfreetype 2.13.2 -> 2.13.4, openssl 1.1.1f -> 1.1.1w
   - verified: eMP-tokenMonitor cross-build (Makefile + CMake) -> ARM ELF
   ```
5. 更新 README/AGENTS.md 里的版本描述

### 5.2 场景 B：新增依赖库（eMP 项目要链新库）

1. 找到库在 SDK 中的产物位置：
   - 已打包的库：`staging_dir/target/usr/lib/libxxx.so*`（头文件在 `usr/include/`）
   - 若 SDK 里没有（如自编译/板子专有），从板子上拷：
     `scp root@<板子IP>:/usr/lib/libxxx.so* $TC/sysroot/usr/lib/`
     头文件同理放到 `$TC/sysroot/usr/include/xxx/`
2. 重新打包 sysroot（§4.4），重新验证（§4.5）
3. 提交信息注明新增库，例如：
   ```
   sysroot: add libcurl (with headers)
   - added for eMP-xxx HTTP download feature
   - tc_sysroot.tar.gz rebuilt (32M -> 34M)
   ```
4. 同步更新 §3「依赖对象」的库清单与 README

### 5.3 场景 C：仅改脚本/文档/工具链文件

直接改 `setup.sh` / `README.md` / `AGENTS.md` / `cmake/build_for_t113s3.cmake`，
提交推送即可，**不需要重新打包 tar.gz**。

### 5.4 通用流程与约定

```bash
# 每个改动一个 commit，提交信息附 Co-Authored-By
git add -A
git commit -m "<subject>

<body 说明变更与验证结果>

Co-Authored-By: WorkBuddy <workbuddy@tencent.com>"
# 推送（认证走 http.extraHeader，见仓库 .git/config，勿提交 token）
git -c credential.helper= push origin main
```

- **任何改动发布前必须通过 §4.5 验证**（至少 Makefile 方式）
- 不要在仓库里放解压后的 `toolchain/`、`sysroot/` 目录（避免 155M+ 冗余）
- 不要把 API Key、板子密码等敏感信息提交进仓库

## 6. tina-sdk 获取

全志 TinaLinux SDK（T113-S3）官方网盘下载（提取码见链接）：

- **百度网盘**：https://pan.baidu.com/s/13SUi3SbRs4Re0EXOmHbAIw?pwd=u770
  （含完整 SDK 源码与预编译工具链；解压后按 README/`build/envsetup.sh` 初始化即可）

> 本仓库的 `toolchain/` 即来自该 SDK 中的
> `prebuilt/gcc/linux-x86/arm/toolchain-sunxi-musl/toolchain`，
> `sysroot/` 来自编译产物 `out/<board>/staging_dir/target`。

## 7. 踩坑清单（维护时必读）

| 坑 | 说明 | 对策 |
|---|---|---|
| symlink | 工具链靠 symlink 工作（wrapper、lib32/lib64 等） | `cp -a`/`tar` 必须保留链接；全程在 Linux 操作 |
| Windows 解压 | Windows 无法创建 symlink，解压即残缺 | 用户必须在 Linux 上解压；仓库只存 tar.gz |
| 共享目录 | `/mnt/share`（VMware）不支持 symlink | 制作/打包在本地磁盘（`/tmp`、`~/`） |
| freetype 头文件 | 在 `compile_dir/.../freetype-*/include`，**不在** staging_dir | 单独并入 `sysroot/usr/include/freetype2/` |
| GitHub 100MB 限制 | 单文件 push 超 100MB 会被拒绝 | 当前 46M/32M 安全；超限则裁剪或拆包 |
| STAGING_DIR | gcc wrapper 依赖它定位 libc 头/库 | 使用方必须 `export STAGING_DIR=$T113_SDK/sysroot` |
| 旧 .o 竞态 | 交叉/本地编译混用 `-j8` 可能把异架构 .o 链进来 | 换工具链后先 `find . -name "*.o" -delete` |

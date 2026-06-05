#!/usr/bin/env python3
"""
apply_portable_patch.py — 为上游 Gridea Pro 源码注入绿色便携模式支持

用法:
    python3 scripts/apply_portable_patch.py <source-directory>

源项目 (Gridea-Pro/gridea-pro) 尚未实现 -tags portable 对应的代码文件。
本脚本在克隆源码后、编译前，对关键文件注入便携模式检测逻辑：

  1. config/config.go  — 配置目录从 %APPDATA% 切换到 exe 同级目录
  2. boot/boot.go      — 默认站点目录从 Documents 切换到 exe 同级目录
  3. boot/boot.go      — WebView2 用户数据目录隔离
  4. boot/boot.go      — 日志目录便携化

检测方式：运行时查找 exe 同目录下的 .portable 标记文件
"""

import os
import sys
import textwrap

# Windows 的 Python 默认编码是 cp1252，无法输出中文。
# 强制将 stdout/stderr 切换到 UTF-8，避免 UnicodeEncodeError。
if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr.encoding and sys.stderr.encoding.lower() != 'utf-8':
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
os.environ['PYTHONIOENCODING'] = 'utf-8'


def patch_file(filepath: str, replacements: list[tuple[str, str]], description: str):
    """对文件执行精确的文本替换"""
    print(f"  修补 {description}...")
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    for i, (old, new) in enumerate(replacements):
        if old not in content:
            print(f"    ⚠ 替换 #{i+1} 未找到匹配文本，跳过（可能已修补）")
            continue
        content = content.replace(old, new, 1)  # 只替换第一次出现
        print(f"    ✔ 替换 #{i+1} 完成")

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  ✔ {description} 修补完成\n")


def main():
    if len(sys.argv) < 2:
        print(f"用法: {sys.argv[0]} <source-directory>")
        sys.exit(1)

    source_dir = sys.argv[1]
    if not os.path.isdir(source_dir):
        print(f"错误: 目录不存在: {source_dir}")
        sys.exit(1)

    print("=" * 50)
    print(" Gridea Pro — 便携模式补丁")
    print("=" * 50)
    print()

    # =========================================================================
    # 补丁 1：config/config.go — 添加便携路径检测 + 修改 NewConfigManager
    # =========================================================================
    config_go = os.path.join(source_dir, "backend", "internal", "config", "config.go")

    # 便携检测函数（插入到 import 块结束后、const 块之前）
    portable_func = textwrap.dedent("""\

        // portableExeDir 检测便携模式并返回 exe 所在目录。
        // 如果 exe 同级目录存在 .portable 标记文件，返回该目录；否则返回空字符串。
        func portableExeDir() string {
        \texe, err := os.Executable()
        \tif err != nil {
        \t\treturn ""
        \t}
        \tdir := filepath.Dir(exe)
        \tif _, err := os.Stat(filepath.Join(dir, ".portable")); err == nil {
        \t\treturn dir
        \t}
        \treturn ""
        }

        """)

    # NewConfigManager 中的便携分支
    portable_config_init = textwrap.dedent("""\
        func NewConfigManager() (*ConfigManager, error) {
        \t// 便携模式：exe 同级目录存在 .portable 标记文件时，使用 exe 目录作为配置目录
        \tif pDir := portableExeDir(); pDir != "" {
        \t\tappConfigDir := filepath.Join(pDir, AppName)
        \t\treturn &ConfigManager{
        \t\t\tconfigDir:  appConfigDir,
        \t\t\tconfigPath: filepath.Join(appConfigDir, ConfigFileName),
        \t\t}, nil
        \t}

        \tconfigDir, err := os.UserConfigDir()""")

    config_replacements = [
        # 1a. 在 const ( 之前插入便携检测函数
        (
            "const (\n",
            portable_func + "const (\n",
        ),
        # 1b. 修改 NewConfigManager 函数开头
        (
            "func NewConfigManager() (*ConfigManager, error) {\n\tconfigDir, err := os.UserConfigDir()",
            portable_config_init,
        ),
    ]

    patch_file(config_go, config_replacements, "config/config.go — 便携配置目录")

    # =========================================================================
    # 补丁 2：boot/boot.go — 默认站点目录 + WebView2 隔离 + 日志目录
    # =========================================================================
    boot_go = os.path.join(source_dir, "backend", "pkg", "boot", "boot.go")

    # 便携检测函数（boot 包独立副本，避免循环依赖）
    portable_boot_func = textwrap.dedent("""\

        // portableBootDir 便携模式检测（boot 包的本地副本，避免循环依赖 config 包）
        func portableBootDir() string {
        \texe, err := os.Executable()
        \tif err != nil {
        \t\treturn ""
        \t}
        \tdir := filepath.Dir(exe)
        \tif _, err := os.Stat(filepath.Join(dir, ".portable")); err == nil {
        \t\treturn dir
        \t}
        \treturn ""
        }

        """)

    boot_replacements = [
        # 2a. 在 func Run( 之前插入便携检测函数
        (
            "func Run(assets embed.FS, version string) {\n",
            portable_boot_func + "func Run(assets embed.FS, version string) {\n",
        ),
        # 2b. 修改默认站点目录的计算逻辑
        (
            "\t// 初始化路径：多站点模式，优先从 Sites 列表找活跃站点\n"
            "\tvar appDir string\n"
            "\thome, _ := os.UserHomeDir()\n"
            "\tdefaultPath := filepath.Join(home, \"Documents\", \"Gridea Pro\")",

            "\t// 初始化路径：多站点模式，优先从 Sites 列表找活跃站点\n"
            "\tvar appDir string\n"
            "\tvar defaultPath string\n"
            "\tif pDir := portableBootDir(); pDir != \"\" {\n"
            "\t\t// 便携模式：站点目录和配置目录都在 exe 同级目录\n"
            "\t\tdefaultPath = filepath.Join(pDir, \"Gridea Pro\")\n"
            "\t\t// 隔离 WebView2 用户数据到便携目录（Windows）\n"
            "\t\tif os.Getenv(\"WEBVIEW2_USER_DATA_FOLDER\") == \"\" {\n"
            "\t\t\tos.Setenv(\"WEBVIEW2_USER_DATA_FOLDER\",\n"
            "\t\t\t\tfilepath.Join(pDir, \"Gridea Pro\", \"webview2\"))\n"
            "\t\t}\n"
            "\t} else {\n"
            "\t\thome, _ := os.UserHomeDir()\n"
            "\t\tdefaultPath = filepath.Join(home, \"Documents\", \"Gridea Pro\")\n"
            "\t}",
        ),
        # 2c. 修改"查看日志"菜单中的路径解析
        (
            "\t\tconfigDir, err := os.UserConfigDir()\n"
            "\t\tif err != nil {\n"
            "\t\t\treturn\n"
            "\t\t}\n"
            "\t\tlogDir := filepath.Join(configDir, config.AppName)",

            "\t\tvar logDir string\n"
            "\t\tif pDir := portableBootDir(); pDir != \"\" {\n"
            "\t\t\tlogDir = filepath.Join(pDir, config.AppName)\n"
            "\t\t} else {\n"
            "\t\t\tconfigDir, err := os.UserConfigDir()\n"
            "\t\t\tif err != nil {\n"
            "\t\t\t\treturn\n"
            "\t\t\t}\n"
            "\t\t\tlogDir = filepath.Join(configDir, config.AppName)\n"
            "\t\t}",
        ),
    ]

    patch_file(boot_go, boot_replacements, "boot/boot.go — 便携站点目录 + WebView2 + 日志")

    # =========================================================================
    # 验证补丁
    # =========================================================================
    print("=" * 50)
    print(" 验证补丁结果...")
    print("=" * 50)

    errors = []

    # 验证 config.go
    with open(config_go, "r", encoding="utf-8") as f:
        config_content = f.read()
    if "portableExeDir" not in config_content:
        errors.append("config.go 缺少 portableExeDir 函数")
    if "pDir := portableExeDir()" not in config_content:
        errors.append("config.go NewConfigManager 缺少便携分支")

    # 验证 boot.go
    with open(boot_go, "r", encoding="utf-8") as f:
        boot_content = f.read()
    if "portableBootDir" not in boot_content:
        errors.append("boot.go 缺少 portableBootDir 函数")
    if "WEBVIEW2_USER_DATA_FOLDER" not in boot_content:
        errors.append("boot.go 缺少 WebView2 隔离逻辑")
    if 'home, _ := os.UserHomeDir()\n\tdefaultPath := filepath.Join(home, "Documents"' in boot_content:
        errors.append("boot.go 默认路径未被修改")

    if errors:
        print("  ✘ 补丁验证失败：")
        for e in errors:
            print(f"    - {e}")
        sys.exit(1)
    else:
        print("  ✔ 所有补丁验证通过")

    print()
    print("=" * 50)
    print(" ✔ 便携模式补丁应用完成！")
    print()
    print(" 修改的文件：")
    print("   - backend/internal/config/config.go")
    print("   - backend/pkg/boot/boot.go")
    print()
    print(" 运行时行为：")
    print("   exe 同级目录存在 .portable → 便携模式（数据在本目录）")
    print("   exe 同级目录无 .portable   → 标准模式（数据在系统目录）")
    print("=" * 50)


if __name__ == "__main__":
    main()

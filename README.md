<div align="center">

# Gridea Pro Portable

### 绿色便携版自动构建

[![Portable Release](https://github.com/hopol/gridea-pro-portable/actions/workflows/portable-release.yml/badge.svg)](https://github.com/hopol/gridea-pro-portable/actions/workflows/portable-release.yml)
[![License](https://img.shields.io/github/license/hopol/gridea-pro-portable?color=blue)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/hopol/gridea-pro-portable?label=Latest)](https://github.com/hopol/gridea-pro-portable/releases/latest)

[下载最新版本 →](https://github.com/hopol/gridea-pro-portable/releases/latest)

---

*不污染系统 · 解压即用 · 整目录迁移 · 全平台支持*

</div>

---

## ✨ 项目说明

本仓库是 [Gridea Pro](https://github.com/Gridea-Pro/gridea-pro) 的 **绿色便携版**（Portable Edition）自动构建仓库。

Gridea Pro 是一款基于 **Go + Wails v2 + Vue 3** 的跨平台静态博客写作客户端，提供内置 Markdown 编辑器、主题系统、多平台部署等功能。本仓库追踪源项目的每次发布，通过 CI 自动构建**不污染系统、解压即用**的绿色便携版本。

---

## 📦 与源项目的关系

| 项目 | 说明 |
|------|------|
| **源项目** | [Gridea-Pro/gridea-pro](https://github.com/Gridea-Pro/gridea-pro) |
| **本仓库** | 自动化构建脚本，拉取源项目源码并编译绿色便携版 |
| **代码补丁** | 编译前通过 Python 脚本注入便携模式路径重定向逻辑 |
| **发布同步** | 源项目发布新 tag 后，在本仓库打相同 tag 即可触发构建 |

---

## 🟢 绿色版定义

**绿色便携版**严格遵循以下原则：

| 原则 | 说明 |
|:----:|------|
| 🔒 | **不污染系统环境变量** — 不设置全局 PATH、不写入注册表 |
| 🛡️ | **不修改系统文件** — 不安装 DLL、不创建系统服务 |
| 🚫 | **不在用户目录创建文件** — 不在 `~/.config`、`AppData`、`~/Library` 写入 |
| 📁 | **所有数据自包含** — 配置、站点数据、主题、缓存全部在程序同级目录 |
| ▶️ | **解压即用** — 整个目录拷贝到任意位置（U 盘、网络驱动器）均可运行 |
| 🔄 | **便携迁移** — 整目录拷贝即可迁移，无需重新配置 |

### 数据存放位置

| 平台 | 数据目录 | 标记文件 |
|------|----------|----------|
| **Windows** | `Gridea Pro.exe` 同级 `gridea-pro-data/` | `.portable` |
| **macOS** | `Gridea Pro.app` 同级 `gridea-pro-data/` | `.app` 内部 |
| **Linux** | `gridea-pro` 二进制同级 `gridea-pro-data/` | `.portable` |

---

## 🚀 快速开始

### Windows

```
1. 下载 gridea-pro-portable-windows-amd64.zip
2. 解压到任意目录（如 D:\GrideaPro、U 盘等）
3. 双击 Gridea Pro.exe 运行
4. 首次运行自动创建 gridea-pro-data/ 目录
```

### macOS

```
1. 下载对应架构的 .zip（Apple Silicon 选 arm64，Intel 选 amd64）
2. 解压到任意目录
3. 双击 Gridea Pro.app 运行
4. 如遇"无法验证开发者"提示，在 系统设置 → 隐私与安全性 中点击"仍要打开"
```

### Linux

```bash
# 1. 下载并解压
tar xzf gridea-pro-portable-linux-amd64.tar.gz

# 2. 安装依赖（仅首次）
# Ubuntu / Debian
sudo apt install libwebkit2gtk-4.1-0 libgtk-3-0
# Fedora
sudo dnf install webkit2gtk4.1 gtk3

# 3. 运行
./gridea-pro.sh
```

---

## ⚙️ 构建与发布

### 触发方式

| 触发方式 | 行为 |
|----------|------|
| **Tag 推送** | 推送 `v*` 开头的 tag → 拉取源项目对应版本 → 构建 + 发布 Release |
| **定时触发** | 每周一 08:00 UTC → 拉取 main 分支 → 构建 + 发布 Release |
| **手动触发** | Actions 页面触发 → 指定源项目 ref → 构建 + 发布 Release |

### 发布策略

每个平台编译完成后**立即独立发布**到 GitHub Release，无需等待其他平台完成。这意味着：

- Windows 版编译完就能下载，不用等 macOS 和 Linux
- 某个平台构建失败不影响其他平台

### 构建流程

```
触发构建
    ↓
拉取源项目源码（tag 或 main）
    ↓
安装依赖（Go 1.25 / Node.js 20 / Wails CLI 2.12）
    ↓
运行 Python 补丁脚本（注入便携模式路径重定向）
    ↓
编译（-tags portable 激活绿色模式）
    ↓
打包便携文件（.zip / .tar.gz）+ SHA256 校验
    ↓
立即发布到 GitHub Release
```

---

## 📥 构建产物

| 文件 | 平台 | 架构 | 格式 |
|------|------|------|------|
| `gridea-pro-portable-windows-amd64.zip` | Windows | x86_64 | ZIP |
| `gridea-pro-portable-windows-arm64.zip` | Windows | ARM64 | ZIP |
| `gridea-pro-portable-macos-arm64.zip` | macOS | Apple Silicon | ZIP |
| `gridea-pro-portable-macos-amd64.zip` | macOS | Intel | ZIP |
| `gridea-pro-portable-linux-amd64.tar.gz` | Linux | x86_64 | tar.gz |
| `*.sha256` | — | — | 校验文件 |

---

## 🗂️ 仓库结构

```
gridea-pro-portable/
├── .github/
│   └── workflows/
│       └── portable-release.yml    # GitHub Actions 工作流（多平台矩阵构建）
├── scripts/
│   ├── apply_portable_patch.py     # 便携模式补丁脚本（Python）
│   ├── sync-upstream.sh            # Linux/macOS 上游同步脚本
│   └── sync-upstream.ps1           # Windows 上游同步脚本
├── patches/                         # 补丁文件目录
├── .gitignore
├── LICENSE                          # GPL-3.0
└── README.md                        # 本文件
```

---

## 🔑 GitHub Secrets

如需启用 OAuth 登录功能，在仓库 **Settings → Secrets and variables → Actions** 中设置：

| Secret | 说明 | 必须 |
|--------|------|:----:|
| `GH_OAUTH_CLIENT_ID` | GitHub OAuth App 客户端 ID | 可选 |
| `GH_OAUTH_CLIENT_SECRET` | GitHub OAuth App 客户端密钥 | 可选 |
| `NETLIFY_CLIENT_ID` | Netlify OAuth 客户端 ID | 可选 |
| `NETLIFY_CLIENT_SECRET` | Netlify OAuth 客户端密钥 | 可选 |
| `VERCEL_CLIENT_ID` | Vercel OAuth 客户端 ID | 可选 |
| `VERCEL_CLIENT_SECRET` | Vercel OAuth 客户端密钥 | 可选 |

> `GITHUB_TOKEN` 由 GitHub Actions 自动提供，无需手动设置。不设置上述密钥时，构建仍可正常完成，仅不包含 OAuth 登录功能。

---

## ❓ 常见问题

<details>
<summary><strong>绿色版和官方安装版有什么区别？</strong></summary>

功能完全相同。区别在于：
- 绿色版不写入系统目录，所有数据在程序同级目录
- 绿色版不生成安装包，解压即用
- 绿色版编译时注入路径重定向代码以改变数据存储位置

</details>

<details>
<summary><strong>如何从安装版迁移到绿色版？</strong></summary>

将安装版的数据目录手动拷贝到绿色版的 `gridea-pro-data/` 下：

| 平台 | 安装版数据位置 |
|------|---------------|
| Windows | `%APPDATA%\Gridea Pro\` |
| macOS | `~/Library/Application Support/Gridea Pro/` |
| Linux | `~/.config/Gridea Pro/` |

</details>

<details>
<summary><strong>Linux 版为什么不打包为 AppImage？</strong></summary>

AppImage 需要 FUSE 运行环境且会在 `~/.cache` 中解压临时文件。绿色版使用自包含目录 + 启动脚本，确保所有数据都在本目录下。

</details>

<details>
<summary><strong>如何验证下载文件的完整性？</strong></summary>

每个构建产物都附带 `.sha256` 校验文件：
```bash
sha256sum -c gridea-pro-portable-linux-amd64.tar.gz.sha256
```

</details>

---

## 📜 许可证

本项目使用 [GPL-3.0](LICENSE) 许可证，与源项目 [Gridea Pro](https://github.com/Gridea-Pro/gridea-pro) 保持一致。

---

<div align="center">

**致谢**

[Gridea Pro](https://github.com/Gridea-Pro/gridea-pro) · [Wails](https://wails.io/) · [Vue.js](https://vuejs.org/) · [Go](https://go.dev/)

</div>

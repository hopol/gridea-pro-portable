#!/usr/bin/env bash
# =============================================================================
# sync-upstream.sh — 拉取上游 Gridea Pro 源码并构建绿色便携版
# =============================================================================
# 用法：
#   ./scripts/sync-upstream.sh [tag|main]
#
# 示例：
#   ./scripts/sync-upstream.sh v1.0.0    # 拉取 v1.0.0 tag
#   ./scripts/sync-upstream.sh main      # 拉取 main 分支（默认）
#
# 环境变量（可选）：
#   GH_OAUTH_CLIENT_ID       — GitHub OAuth 客户端 ID
#   GH_OAUTH_CLIENT_SECRET   — GitHub OAuth 客户端密钥
#   NETLIFY_CLIENT_ID        — Netlify OAuth 客户端 ID
#   NETLIFY_CLIENT_SECRET    — Netlify OAuth 客户端密钥
#   VERCEL_CLIENT_ID         — Vercel OAuth 客户端 ID
#   VERCEL_CLIENT_SECRET     — Vercel OAuth 客户端密钥
#   UPSTREAM_REPO            — 上游仓库地址（默认 https://github.com/Gridea-Pro/gridea-pro.git）
# =============================================================================
set -euo pipefail

# ----- 参数解析 -----
REF="${1:-main}"
UPSTREAM="${UPSTREAM_REPO:-https://github.com/Gridea-Pro/gridea-pro.git}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_DIR="${ROOT_DIR}/source"
BUILD_DIR="${SOURCE_DIR}/build/bin"
OUTPUT_DIR="${ROOT_DIR}/dist"

# ----- 常量 -----
APP_NAME="Gridea Pro"
BIN_SLUG="gridea-pro"
RELEASE_PREFIX="gridea-pro-portable"

echo "============================================"
echo " Gridea Pro Portable — 同步 & 构建"
echo "============================================"
echo "上游仓库: ${UPSTREAM}"
echo "目标 ref: ${REF}"
echo "源码目录: ${SOURCE_DIR}"
echo "输出目录: ${OUTPUT_DIR}"
echo ""

# ----- 第 1 步：拉取源码 -----
echo "[1/6] 拉取上游源码..."
if [[ -d "${SOURCE_DIR}" ]]; then
    echo "  源码目录已存在，清理后重新克隆..."
    rm -rf "${SOURCE_DIR}"
fi

if [[ "${REF}" == "main" ]] || [[ "${REF}" == "master" ]]; then
    git clone --depth 1 "${UPSTREAM}" "${SOURCE_DIR}"
else
    # 先尝试按 tag/branch 克隆
    if ! git clone --depth 1 --branch "${REF}" "${UPSTREAM}" "${SOURCE_DIR}" 2>/dev/null; then
        echo "  无法直接克隆 ref '${REF}'，尝试完整克隆后切换..."
        git clone "${UPSTREAM}" "${SOURCE_DIR}"
        cd "${SOURCE_DIR}"
        git checkout "${REF}"
    fi
fi

cd "${SOURCE_DIR}"
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "  ✔ 源码已就绪（commit: ${COMMIT_HASH}）"
echo ""

# ----- 第 2 步：检测版本 -----
echo "[2/6] 检测版本号..."
VERSION="${REF}"
if [[ "${VERSION}" == v* ]]; then
    VERSION_NUM="${VERSION#v}"
else
    VERSION_NUM="0.0.0-dev"
fi
echo "  版本: ${VERSION}（数字: ${VERSION_NUM}）"
echo ""

# ----- 第 3 步：修补 wails.json -----
echo "[3/6] 修补 wails.json productVersion..."
if command -v node &>/dev/null; then
    node -e "
      const fs = require('fs');
      const j = JSON.parse(fs.readFileSync('wails.json', 'utf8'));
      j.info = j.info || {};
      j.info.productVersion = '${VERSION_NUM}';
      fs.writeFileSync('wails.json', JSON.stringify(j, null, 4) + '\n');
      console.log('  ✔ wails.json productVersion → ${VERSION_NUM}');
    "
else
    echo "  ⚠ node 未安装，跳过 wails.json 修补"
fi
echo ""

# ----- 第 4 步：安装前端依赖 -----
echo "[4/6] 安装前端依赖..."
cd "${SOURCE_DIR}/frontend"
if command -v npm &>/dev/null; then
    npm install --legacy-peer-deps 2>/dev/null || npm install --force
else
    echo "  ⚠ npm 未安装，跳过前端依赖安装"
fi
cd "${SOURCE_DIR}"
echo ""

# ----- 第 5 步：构建 -----
echo "[5/6] 构建绿色便携版..."

# 组装 ldflags
LDFLAGS="-X main.Version=${VERSION_NUM}"
if [[ -n "${GH_OAUTH_CLIENT_ID:-}" ]]; then
    LDFLAGS="${LDFLAGS} -X gridea-pro/backend/internal/service/oauth.githubClientID=${GH_OAUTH_CLIENT_ID}"
    LDFLAGS="${LDFLAGS} -X gridea-pro/backend/internal/service/oauth.githubClientSecret=${GH_OAUTH_CLIENT_SECRET:-}"
fi
if [[ -n "${NETLIFY_CLIENT_ID:-}" ]]; then
    LDFLAGS="${LDFLAGS} -X gridea-pro/backend/internal/service/oauth.netlifyClientID=${NETLIFY_CLIENT_ID}"
    LDFLAGS="${LDFLAGS} -X gridea-pro/backend/internal/service/oauth.netlifyClientSecret=${NETLIFY_CLIENT_SECRET:-}"
fi
if [[ -n "${VERCEL_CLIENT_ID:-}" ]]; then
    LDFLAGS="${LDFLAGS} -X gridea-pro/backend/internal/service/oauth.vercelClientID=${VERCEL_CLIENT_ID}"
    LDFLAGS="${LDFLAGS} -X gridea-pro/backend/internal/service/oauth.vercelClientSecret=${VERCEL_CLIENT_SECRET:-}"
fi

# 检测当前平台
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)       echo "  ⚠ 未知架构: ${ARCH}" ;;
esac

echo "  当前平台: ${OS}/${ARCH}"
echo "  ldflags: ${LDFLAGS}"
echo ""

# 根据平台选择 Wails platform 参数
case "${OS}" in
    darwin)
        WAILS_PLATFORM="darwin/${ARCH}"
        WAILS_TAGS="portable"
        ;;
    linux)
        WAILS_PLATFORM="linux/${ARCH}"
        WAILS_TAGS="portable webkit2_41"
        ;;
    mingw*|msys*|cygwin*)
        OS="windows"
        WAILS_PLATFORM="windows/${ARCH}"
        WAILS_TAGS="portable"
        ;;
    *)
        echo "  ✘ 不支持的操作系统: ${OS}"
        exit 1
        ;;
esac

# 调用 Wails 构建
if command -v wails &>/dev/null; then
    CGO_ENABLED=1 wails build -platform "${WAILS_PLATFORM}" -clean -trimpath \
        -tags "${WAILS_TAGS}" -ldflags "${LDFLAGS}"
else
    echo "  ⚠ wails 未安装，尝试使用 go build 替代..."
    echo "  注意：go build 不包含前端资源，仅用于测试编译"
    CGO_ENABLED=1 go build -tags "${WAILS_TAGS}" \
        -ldflags "${LDFLAGS}" \
        -o "build/bin/${BIN_SLUG}" .
fi

# 构建 MCP 服务器
echo "  构建 MCP 服务器..."
case "${OS}" in
    windows)
        MCP_OUTPUT="build/bin/${BIN_SLUG}-mcp.exe"
        MCP_CGO=1
        ;;
    *)
        MCP_OUTPUT="build/bin/${BIN_SLUG}-mcp"
        MCP_CGO=1
        ;;
esac

CGO_ENABLED=${MCP_CGO} go build -tags portable \
    -ldflags="-s -w -X main.Version=${VERSION_NUM}" \
    -o "${MCP_OUTPUT}" \
    ./backend/cmd/mcp

echo "  ✔ 构建完成"
echo ""

# ----- 第 6 步：打包 -----
echo "[6/6] 打包便携文件..."
mkdir -p "${OUTPUT_DIR}"

# 创建打包暂存区
STAGING="${ROOT_DIR}/.staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"

case "${OS}" in
    darwin)
        # macOS: 打包 .app bundle
        if [[ -d "${BUILD_DIR}/${APP_NAME}.app" ]]; then
            cp -R "${BUILD_DIR}/${APP_NAME}.app" "${STAGING}/"
            # 在 .app 同级放 .portable 标记
            touch "${STAGING}/.portable"
            cd "${STAGING}"
            OUTPUT="${OUTPUT_DIR}/${RELEASE_PREFIX}-macos-${ARCH}.zip"
            ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${OUTPUT}" 2>/dev/null || \
                zip -r "${OUTPUT}" "${APP_NAME}.app"
        fi
        ;;
    linux)
        # Linux: 自包含目录
        cp "${BUILD_DIR}/${APP_NAME}" "${STAGING}/gridea-pro" 2>/dev/null || true
        chmod 755 "${STAGING}/gridea-pro"
        if [[ -f "${BUILD_DIR}/${BIN_SLUG}-mcp" ]]; then
            cp "${BUILD_DIR}/${BIN_SLUG}-mcp" "${STAGING}/"
            chmod 755 "${STAGING}/${BIN_SLUG}-mcp"
        fi
        touch "${STAGING}/.portable"

        # 启动脚本
        cat > "${STAGING}/gridea-pro.sh" << 'LAUNCHER'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export GRIDEA_PRO_PORTABLE=1
export GRIDEA_PRO_DATA_DIR="${SCRIPT_DIR}/gridea-pro-data"
mkdir -p "${GRIDEA_PRO_DATA_DIR}"
exec "${SCRIPT_DIR}/gridea-pro" "$@"
LAUNCHER
        chmod 755 "${STAGING}/gridea-pro.sh"

        cd "${STAGING}"
        OUTPUT="${OUTPUT_DIR}/${RELEASE_PREFIX}-linux-${ARCH}.tar.gz"
        tar czf "${OUTPUT}" .
        ;;
    windows)
        # Windows: 便携 exe + mcp
        if [[ -f "${BUILD_DIR}/${APP_NAME}.exe" ]]; then
            cp "${BUILD_DIR}/${APP_NAME}.exe" "${STAGING}/"
        fi
        if [[ -f "${BUILD_DIR}/${BIN_SLUG}-mcp.exe" ]]; then
            cp "${BUILD_DIR}/${BIN_SLUG}-mcp.exe" "${STAGING}/"
        fi
        touch "${STAGING}/.portable"

        cd "${STAGING}"
        OUTPUT="${OUTPUT_DIR}/${RELEASE_PREFIX}-windows-${ARCH}.zip"
        # PowerShell 压缩
        powershell -Command "Compress-Archive -Path './*' -DestinationPath '${OUTPUT}' -Force" 2>/dev/null || \
            zip -r "${OUTPUT}" .
        ;;
esac

# 清理暂存区
cd "${ROOT_DIR}"
rm -rf "${STAGING}"

echo "  ✔ 输出文件："
ls -lh "${OUTPUT_DIR}/"
echo ""

# ----- 生成校验文件 -----
echo "生成 SHA256SUMS..."
cd "${OUTPUT_DIR}"
if command -v sha256sum &>/dev/null; then
    sha256sum * > SHA256SUMS
elif command -v shasum &>/dev/null; then
    shasum -a 256 * > SHA256SUMS
fi
echo "  ✔ SHA256SUMS 已生成"
cat SHA256SUMS 2>/dev/null || true
echo ""

echo "============================================"
echo " ✔ 绿色便携版构建完成！"
echo " 输出目录: ${OUTPUT_DIR}"
echo "============================================"

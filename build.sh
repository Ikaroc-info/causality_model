#!/usr/bin/env bash
# =============================================================================
# build.sh — Build script for Antigravity Causal
#
# Builds:
#   - Frontend  : React/Vite → static files   (dist/)
#   - Backend   : FastAPI/Python → binary      (release/linux/ and release/windows/)
#
# Usage:
#   ./build.sh              → build both frontend and backend (Linux only)
#   ./build.sh --all        → build frontend + backend for Linux AND Windows (needs Wine)
#   ./build.sh --frontend   → build frontend only
#   ./build.sh --backend-linux   → build backend for Linux only
#   ./build.sh --backend-windows → cross-compile backend for Windows (needs Wine + pyinstaller in Wine)
#
# Requirements:
#   Linux binary  : python3, pip, pyinstaller (auto-installed if missing)
#   Windows binary: wine64, python in Wine (see README for setup)
# =============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

log()     { echo -e "${CYAN}[BUILD]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELEASE_DIR="$SCRIPT_DIR/release"
FRONTEND_OUT="$SCRIPT_DIR/dist"
BACKEND_ENTRY="$SCRIPT_DIR/server.py"
APP_NAME="antigravity_causal"

# ── Parse Arguments ──────────────────────────────────────────────────────────
BUILD_FRONTEND=false
BUILD_LINUX=false
BUILD_WINDOWS=false

if [[ $# -eq 0 ]]; then
    BUILD_FRONTEND=true
    BUILD_LINUX=true
else
    for arg in "$@"; do
        case "$arg" in
            --all)              BUILD_FRONTEND=true; BUILD_LINUX=true; BUILD_WINDOWS=true ;;
            --frontend)         BUILD_FRONTEND=true ;;
            --backend-linux)    BUILD_LINUX=true ;;
            --backend-windows)  BUILD_WINDOWS=true ;;
            --help|-h)
                head -30 "$0" | grep '^#' | sed 's/^# \?//'
                exit 0
                ;;
            *)
                error "Unknown option: $arg"
                echo "Use --help for usage."
                exit 1
                ;;
        esac
    done
fi

echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      Antigravity Causal — Build Script       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
echo ""

mkdir -p "$RELEASE_DIR/linux"
mkdir -p "$RELEASE_DIR/windows"

# ════════════════════════════════════════════════════════════════════════════
# FRONTEND — Build with Vite
# ════════════════════════════════════════════════════════════════════════════
build_frontend() {
    log "Building frontend with Vite..."

    if ! command -v node &>/dev/null; then
        error "node is not installed. Please install Node.js first."
        exit 1
    fi

    cd "$SCRIPT_DIR"

    if [[ ! -d node_modules ]]; then
        log "Installing npm dependencies..."
        npm install
    fi

    npm run build

    success "Frontend built → $FRONTEND_OUT"
    warn "Frontend will be embedded inside the binary (no separate dist/ copy needed)."
}

# ════════════════════════════════════════════════════════════════════════════
# BACKEND — Build with PyInstaller (Linux)
# ════════════════════════════════════════════════════════════════════════════
build_backend_linux() {
    log "Building backend for Linux with PyInstaller..."

    # Use the project venv if it exists, else use system Python
    if [[ -f "$SCRIPT_DIR/venv/bin/python" ]]; then
        PYTHON="$SCRIPT_DIR/venv/bin/python"
        PIP="$SCRIPT_DIR/venv/bin/pip"
        PYINSTALLER="$SCRIPT_DIR/venv/bin/pyinstaller"
    else
        PYTHON="python3"
        PIP="pip3"
        PYINSTALLER="pyinstaller"
    fi

    # Install PyInstaller if missing
    if ! "$PYTHON" -m PyInstaller --version &>/dev/null 2>&1; then
        warn "PyInstaller not found. Installing..."
        "$PIP" install pyinstaller
    fi

    cd "$SCRIPT_DIR"

    # Ensure frontend is built before embedding
    if [[ ! -d "$FRONTEND_OUT" ]]; then
        warn "dist/ not found — building frontend first..."
        build_frontend
    fi

    # Remove any stale spec file before regenerating
    rm -f "$SCRIPT_DIR/build/${APP_NAME}.spec" "$SCRIPT_DIR/${APP_NAME}.spec"

    "$PYTHON" -m PyInstaller \
        --onefile \
        --name "$APP_NAME" \
        --distpath "$RELEASE_DIR/linux" \
        --workpath "$SCRIPT_DIR/build/linux" \
        --add-data "$FRONTEND_OUT:dist" \
        --clean \
        --noconfirm \
        "$BACKEND_ENTRY"

    success "Linux binary → $RELEASE_DIR/linux/$APP_NAME"
}

# ════════════════════════════════════════════════════════════════════════════
# BACKEND — Build with PyInstaller (Windows via Docker + Wine)
# Uses the cdrx/pyinstaller-windows image which has Python + PyInstaller
# pre-installed inside Wine — no manual Wine setup required.
# ════════════════════════════════════════════════════════════════════════════
build_backend_windows() {
    log "Building backend for Windows via Docker..."

    if ! command -v docker &>/dev/null; then
        error "Docker is not installed."
        echo ""
        echo "  Install Docker:"
        echo "    sudo apt install docker.io"
        echo "    sudo usermod -aG docker \$USER   # then log out and back in"
        echo ""
        exit 1
    fi

    # Check Docker daemon is running
    if ! docker info &>/dev/null 2>&1; then
        error "Docker daemon is not running or you don't have permission."
        echo "  Try: sudo systemctl start docker"
        echo "  Or add yourself to the docker group: sudo usermod -aG docker \$USER"
        exit 1
    fi

    cd "$SCRIPT_DIR"

    # Ensure frontend is built before embedding
    if [[ ! -d "$FRONTEND_OUT" ]]; then
        warn "dist/ not found — building frontend first..."
        build_frontend
    fi

    log "Pulling Docker image (first run only — this may take a few minutes)..."
    docker pull cdrx/pyinstaller-windows:python3

    log "Running PyInstaller inside Docker for Windows target..."
    # NOTE: cdrx/pyinstaller-windows runs inside Wine, which cannot resolve
    # Linux paths for --distpath/--workpath. We let PyInstaller use its
    # default output location (./dist/ inside the mounted volume) and then
    # move the .exe to release/windows/ from the host side afterward.
    docker run --rm \
        -v "$SCRIPT_DIR:/src" \
        -w /src \
        --entrypoint bash \
        cdrx/pyinstaller-windows:python3 \
        -c "
            source /root/.bashrc &&
            pip install -r requirements.txt --quiet &&
            python -c 'import sys; sys.setrecursionlimit(5000); import PyInstaller.__main__; sys.exit(PyInstaller.__main__.run())' --onefile \
                --name '${APP_NAME}' \
                --add-data 'dist;dist' \
                --clean \
                --noconfirm \
                server.py
        "

    # PyInstaller writes to ./dist/ by default; move the exe to release/
    WIN_EXE="$SCRIPT_DIR/dist/${APP_NAME}.exe"
    if [[ -f "$WIN_EXE" ]]; then
        mv "$WIN_EXE" "$RELEASE_DIR/windows/${APP_NAME}.exe"
        success "Windows binary → $RELEASE_DIR/windows/${APP_NAME}.exe"
    else
        error "Build completed but .exe not found (expected: $WIN_EXE)"
        error "Contents of dist/: $(ls "$SCRIPT_DIR/dist/" 2>/dev/null || echo 'directory empty or missing')"
        exit 1
    fi
}

# ════════════════════════════════════════════════════════════════════════════
# RUN
# ════════════════════════════════════════════════════════════════════════════
$BUILD_FRONTEND && build_frontend
$BUILD_LINUX    && build_backend_linux
$BUILD_WINDOWS  && build_backend_windows

echo ""
echo -e "${GREEN}${BOLD}Build complete!${RESET}"
echo ""
echo -e "  ${BOLD}Release layout:${RESET}"
if $BUILD_LINUX; then
    echo -e "    release/linux/${APP_NAME}        ← Linux binary (frontend embedded)"
fi
if $BUILD_WINDOWS; then
    echo -e "    release/windows/${APP_NAME}.exe  ← Windows binary (frontend embedded)"
fi
echo ""
echo -e "  ${BOLD}Run the server:${RESET}"
echo -e "    Linux  : ./release/linux/${APP_NAME}"
echo -e "    Windows: .\\release\\windows\\${APP_NAME}.exe"
echo ""

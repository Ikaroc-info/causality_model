#!/usr/bin/env bash
#
# Setup and run the Causality Model application.
#
# This script:
#   1. Checks that Python 3.11 is available (Tkinter requires system Python)
#   2. Creates a virtual environment (.venv)
#   3. Installs requirements from requirements.txt
#   4. Launches app.py
#

set -euo pipefail

# --- Configuration ---
PYTHON_MAJOR_MINOR="3.11"
VENV_DIR=".venv"
REQUIREMENTS_FILE="requirements.txt"
APP_FILE="app.py"

# --- Move to script directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Causality Model - Setup & Launch${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# --- Step 1: Find Python 3.11 ---
echo -e "${YELLOW}[1/4] Checking for Python ${PYTHON_MAJOR_MINOR}...${NC}"

PYTHON_CMD=""
for cmd in python3.11 python3 python; do
    if command -v "$cmd" &>/dev/null; then
        version_output=$("$cmd" --version 2>&1)
        if echo "$version_output" | grep -qE "Python 3\.11"; then
            PYTHON_CMD="$cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo -e "  ${RED}Python ${PYTHON_MAJOR_MINOR} not found.${NC}"
    echo ""
    echo -e "  ${YELLOW}Please install it:${NC}"
    if command -v apt-get &>/dev/null; then
        echo -e "  ${CYAN}  sudo apt install python3.11 python3.11-venv python3.11-tk${NC}"
    elif command -v dnf &>/dev/null; then
        echo -e "  ${CYAN}  sudo dnf install python3.11 python3.11-tkinter${NC}"
    elif command -v pacman &>/dev/null; then
        echo -e "  ${CYAN}  sudo pacman -S python311 tk${NC}"
    elif command -v brew &>/dev/null; then
        echo -e "  ${CYAN}  brew install python@3.11 python-tk@3.11${NC}"
    else
        echo -e "  ${CYAN}  https://www.python.org/downloads/${NC}"
    fi
    exit 1
fi

version_output=$("$PYTHON_CMD" --version 2>&1)
echo -e "  ${GREEN}Found: ${version_output} (${PYTHON_CMD})${NC}"

# --- Paths ---
VENV_PYTHON="$SCRIPT_DIR/$VENV_DIR/bin/python"
VENV_PIP="$SCRIPT_DIR/$VENV_DIR/bin/pip"

# --- Step 2: Create virtual environment ---
echo ""
echo -e "${YELLOW}[2/4] Setting up virtual environment...${NC}"

if [ ! -d "$VENV_DIR" ]; then
    echo -e "  Creating virtual environment in '${VENV_DIR}'..."
    "$PYTHON_CMD" -m venv "$VENV_DIR"
    echo -e "  ${GREEN}Virtual environment created.${NC}"
else
    echo -e "  ${GREEN}Virtual environment already exists, skipping creation.${NC}"
fi

if [ ! -f "$VENV_PYTHON" ]; then
    echo -e "  ${RED}ERROR: venv Python not found at ${VENV_PYTHON}${NC}"
    exit 1
fi

# --- Step 3: Install requirements ---
echo ""
echo -e "${YELLOW}[3/4] Installing dependencies...${NC}"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "  ${RED}ERROR: ${REQUIREMENTS_FILE} not found!${NC}"
    exit 1
fi

echo -e "  Upgrading pip..."
"$VENV_PYTHON" -m pip install --upgrade pip --quiet 2>&1 | tail -1 || true

echo -e "  Installing packages from ${REQUIREMENTS_FILE} (this may take a few minutes)..."
"$VENV_PIP" install -r "$REQUIREMENTS_FILE"

if [ $? -ne 0 ]; then
    echo -e "  ${RED}ERROR: Failed to install some dependencies.${NC}"
    exit 1
fi
echo -e "  ${GREEN}All dependencies installed!${NC}"

# --- Step 4: Launch the application ---
echo ""
echo -e "${YELLOW}[4/4] Launching application...${NC}"
echo -e "  ${GRAY}Running: ${VENV_PYTHON} ${APP_FILE}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

"$VENV_PYTHON" "$APP_FILE"

echo ""
echo -e "${CYAN}Application closed.${NC}"

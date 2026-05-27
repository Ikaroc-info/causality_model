<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    This script:
    0. Cleans up previous local Python install dir and .venv
    1. Downloads Python 3.11 from python.org and installs it locally (no admin required)
       - Includes Tcl/Tk for tkinter support (Include_tcltk=1)
    2. Creates a virtual environment (.venv)
    3. Installs requirements from requirements.txt
    4. Launches app.py
#>

# --- Configuration ---
$PYTHON_VERSION    = "3.11.9"
$VENV_DIR          = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"

$INSTALLER_NAME = "python-$PYTHON_VERSION-amd64.exe"
$PYTHON_URL     = "https://www.python.org/ftp/python/$PYTHON_VERSION/$INSTALLER_NAME"

# --- Move to script directory ---
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Causality Model - Setup & Launch"      -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Paths ---
$pythonDir  = "$env:LOCALAPPDATA\Programs\CausalityModelPython"
$pythonExe  = "$pythonDir\python.exe"
$venvPython = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip    = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

Write-Host "  [DEBUG] Script dir : $PSScriptRoot" -ForegroundColor Gray
Write-Host "  [DEBUG] Python dir : $pythonDir"    -ForegroundColor Gray
Write-Host ""

# =============================================================================
# Step 0 - Clean previous state
# =============================================================================
Write-Host "[0/4] Cleaning previous installation..." -ForegroundColor Yellow

if (Test-Path $pythonDir) {
    Write-Host "  Removing previous Python dir: $pythonDir" -ForegroundColor Gray
    Remove-Item -Recurse -Force $pythonDir -ErrorAction SilentlyContinue
    if (Test-Path $pythonDir) {
        Write-Host "  WARNING: could not fully remove Python dir (files in use?)." -ForegroundColor Yellow
    } else {
        Write-Host "  Python dir removed." -ForegroundColor Green
    }
} else {
    Write-Host "  No previous Python dir found." -ForegroundColor Gray
}

if (Test-Path $VENV_DIR) {
    Write-Host "  Removing previous .venv..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $VENV_DIR -ErrorAction SilentlyContinue
    if (Test-Path $VENV_DIR) {
        Write-Host "  WARNING: could not fully remove .venv (files in use?)." -ForegroundColor Yellow
    } else {
        Write-Host "  .venv removed." -ForegroundColor Green
    }
} else {
    Write-Host "  No previous .venv found." -ForegroundColor Gray
}

Write-Host "  Cleanup done." -ForegroundColor Green
Write-Host ""

# =============================================================================
# Step 1 - Download and install Python 3.11 (with tkinter / Tcl-Tk)
# =============================================================================
Write-Host "[1/4] Installing Python $PYTHON_VERSION (with tkinter)..." -ForegroundColor Yellow

$installerPath = "$PSScriptRoot\$INSTALLER_NAME"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "  Downloading Python installer (~25 MB)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $PYTHON_URL -OutFile $installerPath -UseBasicParsing
    $size = [math]::Round((Get-Item $installerPath).Length / 1MB, 1)
    Write-Host "  Download complete ($size MB)." -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to download Python installer: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# Install silently into our own dir.
# Include_tcltk=1  → ensures tkinter, Tcl/Tk DLLs are included.
# NOTE: we do NOT run msiexec /x to uninstall old components first —
#       that was breaking shared MSI state and leaving Lib/ missing.
$targetDirArg = 'TargetDir="' + $pythonDir + '"'
$installArgs  = @(
    "/quiet", "/norestart",
    "InstallAllUsers=0",
    "PrependPath=0",
    "Include_test=0",
    "Include_launcher=0",
    "Include_doc=0",
    "Include_tcltk=1",
    $targetDirArg
)

Write-Host "  Running installer (this may take 1-2 minutes)..." -ForegroundColor Gray
Write-Host "  [DEBUG] TargetDir: $pythonDir" -ForegroundColor Gray

# Start the bootstrapper and wait fully for it.
# The Python installer bootstrapper spawns one or more msiexec child processes.
# We wait for the bootstrapper itself with a generous timeout (10 min).
$proc = Start-Process -FilePath $installerPath -ArgumentList $installArgs `
                      -WindowStyle Hidden -PassThru -Wait
$exitCode = $proc.ExitCode

Remove-Item $installerPath -ErrorAction SilentlyContinue

Write-Host "  Installer exit code: $exitCode" -ForegroundColor Gray

if ($exitCode -ne 0) {
    Write-Host "  ERROR: Python installation failed (exit code $exitCode)." -ForegroundColor Red
    Write-Host "    1602 = UAC cancelled  |  1603 = fatal error  |  1618 = another install running" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"; exit 1
}

# Verify installation
Write-Host "  [DEBUG] Contents of '$pythonDir':" -ForegroundColor Gray
if (Test-Path $pythonDir) {
    Get-ChildItem $pythonDir | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor Gray }
} else {
    Write-Host "    (directory not found!)" -ForegroundColor Red
}

if (-not (Test-Path $pythonExe)) {
    Write-Host "  ERROR: python.exe not found after install at $pythonExe" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# *** THE KEY FIX ***
# Set PYTHONHOME so Python always knows where its Lib/ and DLLs/ are,
# regardless of registry state or current working directory.
# Without this, Python searches relative to CWD and fails with
# "failed to get the Python codec of the filesystem encoding".
$env:PYTHONHOME       = $pythonDir
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"

$ver = & $pythonExe --version 2>&1
Write-Host "  Installed: $ver" -ForegroundColor Green

# Verify tkinter is available
Write-Host "  Checking tkinter..." -ForegroundColor Gray
$tkCheck = & $pythonExe -c "import tkinter; print('tkinter OK')" 2>&1
if ($tkCheck -like "*OK*") {
    Write-Host "  tkinter: OK" -ForegroundColor Green
} else {
    Write-Host "  WARNING: tkinter check failed: $tkCheck" -ForegroundColor Yellow
}
Write-Host ""

# =============================================================================
# Step 2 - Create virtual environment
# =============================================================================
Write-Host "[2/4] Setting up virtual environment..." -ForegroundColor Yellow

Write-Host "  Creating virtual environment in '$VENV_DIR'..."
& $pythonExe -X utf8 -m venv $VENV_DIR
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to create virtual environment (exit $LASTEXITCODE)." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

if (-not (Test-Path $venvPython)) {
    Write-Host "  ERROR: venv Python not found at $venvPython" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

Write-Host "  Virtual environment created." -ForegroundColor Green
Write-Host ""

# =============================================================================
# Step 3 - Install requirements
# =============================================================================
Write-Host "[3/4] Installing dependencies..." -ForegroundColor Yellow

if (-not (Test-Path $REQUIREMENTS_FILE)) {
    Write-Host "  ERROR: $REQUIREMENTS_FILE not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

Write-Host "  Upgrading pip..."
& $venvPython -m pip install --upgrade pip --quiet

Write-Host "  Installing packages from $REQUIREMENTS_FILE (may take a few minutes)..."
& $venvPip install -r $REQUIREMENTS_FILE
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to install some dependencies." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
Write-Host "  All dependencies installed!" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Step 4 - Launch the application
# =============================================================================
Write-Host "[4/4] Launching application..." -ForegroundColor Yellow
Write-Host "  Running: $venvPython $APP_FILE" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

& $venvPython $APP_FILE

Write-Host ""
Write-Host "Application closed." -ForegroundColor Cyan
Read-Host "Press Enter to exit"

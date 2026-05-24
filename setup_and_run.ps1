<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    This script:
    1. Downloads Python 3.11 from python.org and installs it locally
    2. Creates a virtual environment (.venv)
    3. Installs requirements from requirements.txt
    4. Launches app.py
#>

# --- Configuration ---
$PYTHON_VERSION = "3.11.9"
$PYTHON_DIR = ".python"
$VENV_DIR = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE = "app.py"

# Official Python installer from python.org
$INSTALLER_NAME = "python-$PYTHON_VERSION-amd64.exe"
$PYTHON_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/$INSTALLER_NAME"

# --- Move to script directory ---
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Causality Model - Setup & Launch" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Paths (absolute) ---
$pythonDir = Join-Path $PSScriptRoot $PYTHON_DIR
$pythonExe = Join-Path $pythonDir "python.exe"
$venvPython = Join-Path $PSScriptRoot "$VENV_DIR\Scripts\python.exe"
$venvPip = Join-Path $PSScriptRoot "$VENV_DIR\Scripts\pip.exe"

# --- Step 1: Download and install Python 3.11 locally ---
Write-Host "[1/4] Preparing Python $PYTHON_VERSION..." -ForegroundColor Yellow

if (Test-Path $pythonExe) {
    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "  Already installed: $versionOutput" -ForegroundColor Green
} else {
    Write-Host "  Downloading Python $PYTHON_VERSION from python.org..." -ForegroundColor Yellow
    Write-Host "  URL: $PYTHON_URL" -ForegroundColor Gray

    $installerPath = Join-Path $PSScriptRoot $INSTALLER_NAME

    # Download the official installer
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $PYTHON_URL -OutFile $installerPath -UseBasicParsing
        Write-Host "  Download complete." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to download Python installer." -ForegroundColor Red
        Write-Host "  Please check your internet connection and try again." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Install silently to local directory (no admin, no PATH modification)
    Write-Host "  Installing Python $PYTHON_VERSION locally into '$PYTHON_DIR'..." -ForegroundColor Yellow
    Write-Host "  (No admin rights required, no system changes)" -ForegroundColor Gray

    $installArgs = @(
        "/quiet",
        "InstallAllUsers=0",
        "PrependPath=0",
        "Include_test=0",
        "Include_launcher=0",
        "Include_doc=0",
        "TargetDir=$pythonDir"
    )
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    # Clean up installer
    Remove-Item $installerPath -ErrorAction SilentlyContinue

    if ($process.ExitCode -ne 0) {
        Write-Host "  ERROR: Python installation failed (exit code $($process.ExitCode))." -ForegroundColor Red
        Write-Host "  Try downloading and installing Python $PYTHON_VERSION manually." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    if (-not (Test-Path $pythonExe)) {
        Write-Host "  ERROR: Python executable not found after installation at $pythonExe" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }

    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "  Installed: $versionOutput" -ForegroundColor Green
}

# --- Step 2: Create virtual environment ---
Write-Host ""
Write-Host "[2/4] Setting up virtual environment..." -ForegroundColor Yellow

if (-not (Test-Path $VENV_DIR)) {
    Write-Host "  Creating virtual environment in '$VENV_DIR'..."
    & $pythonExe -m venv $VENV_DIR

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to create virtual environment." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Host "  Virtual environment created." -ForegroundColor Green
} else {
    Write-Host "  Virtual environment already exists, skipping creation." -ForegroundColor Green
}

if (-not (Test-Path $venvPython)) {
    Write-Host "  ERROR: venv Python not found at $venvPython" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# --- Step 3: Install requirements ---
Write-Host ""
Write-Host "[3/4] Installing dependencies..." -ForegroundColor Yellow

if (-not (Test-Path $REQUIREMENTS_FILE)) {
    Write-Host "  ERROR: $REQUIREMENTS_FILE not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "  Upgrading pip..."
& $venvPython -m pip install --upgrade pip --quiet 2>&1 | Out-Null

Write-Host "  Installing packages from $REQUIREMENTS_FILE (this may take a few minutes)..."
& $venvPip install -r $REQUIREMENTS_FILE

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to install some dependencies." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "  All dependencies installed!" -ForegroundColor Green

# --- Step 4: Launch the application ---
Write-Host ""
Write-Host "[4/4] Launching application..." -ForegroundColor Yellow
Write-Host "  Running: $venvPython $APP_FILE" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

& $venvPython $APP_FILE

Write-Host ""
Write-Host "Application closed." -ForegroundColor Cyan
Read-Host "Press Enter to exit"

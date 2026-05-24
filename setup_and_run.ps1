<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    This script:
    1. Downloads Python 3.11 (embeddable package) from python.org
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

# Embeddable package: no installer, no admin/UAC required, ~10MB
$EMBED_ZIP_NAME = "python-$PYTHON_VERSION-embed-amd64.zip"
$EMBED_URL = "https://www.python.org/ftp/python/$PYTHON_VERSION/$EMBED_ZIP_NAME"
$GET_PIP_URL = "https://bootstrap.pypa.io/get-pip.py"

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

# --- Step 1: Download embeddable Python 3.11 ---
Write-Host "[1/4] Preparing Python $PYTHON_VERSION..." -ForegroundColor Yellow

if (Test-Path $pythonExe) {
    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "  Already installed: $versionOutput" -ForegroundColor Green
} else {
    # -- 1a. Download the embeddable zip --
    Write-Host "  Downloading Python $PYTHON_VERSION embeddable package..." -ForegroundColor Yellow
    Write-Host "  URL: $EMBED_URL" -ForegroundColor Gray

    $zipPath = Join-Path $PSScriptRoot $EMBED_ZIP_NAME

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $EMBED_URL -OutFile $zipPath -UseBasicParsing
        Write-Host "  Download complete." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to download Python embeddable package." -ForegroundColor Red
        Write-Host "  Please check your internet connection and try again." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    # -- 1b. Extract the zip --
    Write-Host "  Extracting to '$PYTHON_DIR'..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $pythonDir -Force
    Remove-Item $zipPath -ErrorAction SilentlyContinue

    if (-not (Test-Path $pythonExe)) {
        Write-Host "  ERROR: python.exe not found after extraction at: $pythonExe" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }

    # -- 1c. Enable site-packages (required so pip and venv work) --
    $pthFile = Get-ChildItem -Path $pythonDir -Filter "python*._pth" | Select-Object -First 1
    if ($pthFile) {
        $pthContent = Get-Content $pthFile.FullName
        $pthContent = $pthContent -replace "#import site", "import site"
        Set-Content -Path $pthFile.FullName -Value $pthContent
        Write-Host "  Enabled site-packages in $($pthFile.Name)" -ForegroundColor Green
    }

    # -- 1d. Download and install pip --
    Write-Host "  Installing pip..." -ForegroundColor Yellow
    $getPipPath = Join-Path $pythonDir "get-pip.py"
    try {
        Invoke-WebRequest -Uri $GET_PIP_URL -OutFile $getPipPath -UseBasicParsing
    } catch {
        Write-Host "  ERROR: Failed to download get-pip.py." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    & $pythonExe $getPipPath --quiet
    Remove-Item $getPipPath -ErrorAction SilentlyContinue

    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "  Ready: $versionOutput" -ForegroundColor Green
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

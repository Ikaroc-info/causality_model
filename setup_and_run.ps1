<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    This script:
    1. Downloads Python 3.11 via NuGet (full stdlib: tkinter, venv, etc.) - no admin required
    2. Creates a virtual environment (.venv)
    3. Installs requirements from requirements.txt
    4. Launches app.py
#>

# --- Configuration ---
$PYTHON_VERSION = "3.11.9"
$PYTHON_DIR     = ".python"
$VENV_DIR       = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"

# NuGet Python package: full stdlib (tkinter included), no installer, no UAC
# The .nupkg is simply a renamed zip archive
$NUGET_PKG_VERSION = "3.11.9"
$NUGET_URL = "https://globalcdn.nuget.org/packages/python.$NUGET_PKG_VERSION.nupkg"

# --- Move to script directory ---
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Causality Model - Setup & Launch"      -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Paths ---
$pythonDir  = Join-Path $PSScriptRoot $PYTHON_DIR
$pythonExe  = Join-Path $pythonDir "tools\python.exe"
$venvDir    = Join-Path $PSScriptRoot $VENV_DIR
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$venvPip    = Join-Path $venvDir "Scripts\pip.exe"

# --- Step 1: Download Python via NuGet ---
Write-Host "[1/4] Preparing Python $PYTHON_VERSION..." -ForegroundColor Yellow

if (Test-Path $pythonExe) {
    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "  Already installed: $versionOutput" -ForegroundColor Green
} else {
    Write-Host "  Downloading Python $PYTHON_VERSION from NuGet (full install, includes tkinter)..." -ForegroundColor Yellow
    Write-Host "  URL: $NUGET_URL" -ForegroundColor Gray

    $nupkgPath = Join-Path $PSScriptRoot "python.nupkg.zip"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $NUGET_URL -OutFile $nupkgPath -UseBasicParsing
        Write-Host "  Download complete." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to download Python from NuGet." -ForegroundColor Red
        Write-Host "  Details: $_" -ForegroundColor Gray
        Write-Host "  Please check your internet connection and try again." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    # .nupkg is a zip — extract directly
    Write-Host "  Extracting to '$PYTHON_DIR'..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
    Expand-Archive -Path $nupkgPath -DestinationPath $pythonDir -Force
    Remove-Item $nupkgPath -ErrorAction SilentlyContinue

    if (-not (Test-Path $pythonExe)) {
        Write-Host "  ERROR: python.exe not found after extraction." -ForegroundColor Red
        Write-Host "  Expected: $pythonExe" -ForegroundColor Gray
        Write-Host "  Contents of $pythonDir :" -ForegroundColor Gray
        Get-ChildItem $pythonDir | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Read-Host "Press Enter to exit"
        exit 1
    }

    $versionOutput = & $pythonExe --version 2>&1
    Write-Host "  Ready: $versionOutput" -ForegroundColor Green
}

# --- Step 2: Create virtual environment ---
Write-Host ""
Write-Host "[2/4] Setting up virtual environment..." -ForegroundColor Yellow

if (-not (Test-Path $venvDir)) {
    Write-Host "  Creating virtual environment in '$VENV_DIR'..."
    & $pythonExe -m venv $venvDir

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to create virtual environment." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Host "  Virtual environment created." -ForegroundColor Green
} else {
    Write-Host "  Virtual environment already exists, skipping." -ForegroundColor Green
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

<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    This script:
    1. Downloads Python 3.11 from python.org and installs it locally (no admin required)
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

# --- Paths (absolute) ---
# $pythonDir is set directly as absolute path - no Join-Path with PSScriptRoot
# to avoid the bug where Join-Path(absolute, absolute) = PSScriptRoot + absolute.
$pythonDir  = "$env:LOCALAPPDATA\Programs\CausalityModelPython"
$pythonExe  = "$pythonDir\python.exe"
$venvPython = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip    = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

# --- Step 1: Download and install Python 3.11 locally ---
Write-Host "[1/4] Preparing Python $PYTHON_VERSION..." -ForegroundColor Yellow

# Guard: the Windows Store Python stub (WindowsApps\python.exe) is NOT a real
# Python - it just opens the Store. Treat it as absent.
$isStoreStub = $pythonExe -like "*WindowsApps*"

if ((Test-Path $pythonExe) -and (-not $isStoreStub)) {
    $ver = & $pythonExe --version 2>&1
    Write-Host "  Already installed: $ver" -ForegroundColor Green
} else {
    if ($isStoreStub) {
        Write-Host "  [INFO] Windows Store Python stub detected - installing real Python." -ForegroundColor Yellow
    }
    # -- Diagnostics --
    Write-Host "  [DEBUG] PSScriptRoot  : $PSScriptRoot" -ForegroundColor Gray
    Write-Host "  [DEBUG] pythonDir     : $pythonDir" -ForegroundColor Gray
    Write-Host "  [DEBUG] pythonExe     : $pythonExe" -ForegroundColor Gray

    Write-Host "  Downloading Python $PYTHON_VERSION from python.org..." -ForegroundColor Yellow
    $installerPath = Join-Path $PSScriptRoot $INSTALLER_NAME

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $PYTHON_URL -OutFile $installerPath -UseBasicParsing
        $installerSize = (Get-Item $installerPath).Length
        Write-Host "  Download complete. File size: $([math]::Round($installerSize/1MB, 1)) MB" -ForegroundColor Green
        if ($installerSize -lt 1MB) {
            Write-Host "  WARNING: file seems too small, download may have failed." -ForegroundColor Red
        }
    } catch {
        Write-Host "  ERROR: Failed to download Python installer: $_" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Use Start-Process -Wait (more reliable than & for MSI-based installers
    # that may spawn a child msiexec process).
    # TargetDir is passed as the last element of an array: PowerShell joins with
    # spaces, and the inner quotes survive because they are part of the string value.
    Write-Host "  [DEBUG] TargetDir     : $pythonDir" -ForegroundColor Gray
    Write-Host "  Installing Python $PYTHON_VERSION..." -ForegroundColor Yellow

    $targetDirArg = 'TargetDir="' + $pythonDir + '"'
    $installArgs  = @("/quiet", "InstallAllUsers=0", "PrependPath=0",
                      "Include_test=0", "Include_launcher=0", "Include_doc=0",
                      $targetDirArg)

    $process  = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
    $exitCode = $process.ExitCode
    Write-Host "  [DEBUG] Installer exit code: $exitCode" -ForegroundColor Gray

    Remove-Item $installerPath -ErrorAction SilentlyContinue

    # Poll for python.exe in case msiexec is still running in the background
    if (-not (Test-Path $pythonExe)) {
        Write-Host "  python.exe not yet present, waiting for msiexec to finish (up to 3 min)..." -ForegroundColor Yellow
        $timeout = 180
        $elapsed = 0
        while (-not (Test-Path $pythonExe) -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 3
            $elapsed += 3
            Write-Host "  ... $elapsed s" -ForegroundColor Gray
        }
    }

    if ($exitCode -ne 0) {
        Write-Host "  ERROR: Python installation failed (exit code $exitCode)." -ForegroundColor Red
        Write-Host "  Common causes:" -ForegroundColor Yellow
        Write-Host "    - Exit code 1602 : user cancelled the UAC prompt" -ForegroundColor Yellow
        Write-Host "    - Exit code 1603 : fatal error during installation" -ForegroundColor Yellow
        Write-Host "    - Exit code 1618 : another install is already running" -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }

    # List what was actually created in pythonDir (even if python.exe is missing)
    Write-Host "  [DEBUG] Contents of '$pythonDir' after install:" -ForegroundColor Gray
    if (Test-Path $pythonDir) {
        Get-ChildItem $pythonDir | ForEach-Object {
            Write-Host "    $($_.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Host "    (directory does not exist)" -ForegroundColor Red
    }

    if (-not (Test-Path $pythonExe)) {
        Write-Host "  ERROR: python.exe not found after installation." -ForegroundColor Red
        Write-Host "  Expected: $pythonExe" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Searching for python.exe on this machine..." -ForegroundColor Yellow
        $found = Get-ChildItem -Path $env:LOCALAPPDATA, $env:APPDATA, "C:\Python*", "C:\Program Files\Python*" `
                               -Filter "python.exe" -Recurse -ErrorAction SilentlyContinue |
                 Select-Object -First 5 FullName
        if ($found) {
            $found | ForEach-Object { Write-Host "    Found: $($_.FullName)" -ForegroundColor Cyan }
        } else {
            Write-Host "    None found." -ForegroundColor Gray
        }
        Read-Host "Press Enter to exit"
        exit 1
    }

    $ver = & $pythonExe --version 2>&1
    Write-Host "  Installed: $ver" -ForegroundColor Green
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

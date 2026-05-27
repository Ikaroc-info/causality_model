<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    Installs Python 3.11 (with tkinter) using 3 methods tried in order:
      Method 1 - NuGet package  (no admin, no installer, tkinter included)
      Method 2 - msiexec /a    (extract the .exe without installing, no admin)
      Method 3 - User interaction (asks user to install Python manually)
    Then creates a venv, installs requirements, and launches app.py.
#>

# --- Configuration ---
$PYTHON_VERSION    = "3.11.9"
$VENV_DIR          = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"

# Local Python dir (inside the project, ignored by git)
$pythonDir  = "$PSScriptRoot\python_env"
$pythonExe  = "$pythonDir\python.exe"
$venvPython = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip    = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

Set-Location -Path $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Causality Model - Setup & Launch"      -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Helper ---
# IMPORTANT: always set PYTHONHOME before testing so Python can find its
# stdlib regardless of registry state or current working directory.
function Test-PythonOk {
    param([string]$exe)
    if (-not (Test-Path $exe)) { return $false }
    $savedHome        = $env:PYTHONHOME
    $env:PYTHONHOME   = Split-Path $exe
    $ver = & $exe --version 2>&1
    $tk  = & $exe -c "import tkinter; print('ok')" 2>&1
    $env:PYTHONHOME   = $savedHome
    return ($ver -like "Python 3.*") -and ($tk -like "*ok*")
}

# =============================================================================
# Step 0 - Clean previous state
# =============================================================================
Write-Host "[0/4] Cleaning previous installation..." -ForegroundColor Yellow

foreach ($dir in @($pythonDir, $VENV_DIR)) {
    if (Test-Path $dir) {
        Write-Host "  Removing: $dir" -ForegroundColor Gray
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        if (Test-Path $dir) {
            Write-Host "  WARNING: could not fully remove $dir (files in use?)" -ForegroundColor Yellow
        } else {
            Write-Host "  Removed OK." -ForegroundColor Green
        }
    }
}
Write-Host ""

# =============================================================================
# Step 1 - Install Python (3 methods in cascade)
# =============================================================================
Write-Host "[1/4] Installing Python $PYTHON_VERSION with tkinter..." -ForegroundColor Yellow

$installed = $false

# ---------------------------------------------------------------------------
# Method 1 - NuGet package (ZIP, no admin, tkinter included)
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  [Method 1/3] Trying NuGet package..." -ForegroundColor Cyan

try {
    $nupkgUrl  = "https://www.nuget.org/api/v2/package/python/$PYTHON_VERSION"
    $nupkgPath = "$env:TEMP\python_nuget_$PYTHON_VERSION.zip"
    $rawDir    = "$env:TEMP\python_nuget_raw_$PYTHON_VERSION"

    Write-Host "    Downloading NuGet package (~30 MB)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -UseBasicParsing

    $sizeMB = [math]::Round((Get-Item $nupkgPath).Length / 1MB, 1)
    Write-Host "    Download complete ($sizeMB MB)." -ForegroundColor Gray

    Write-Host "    Extracting..." -ForegroundColor Gray
    if (Test-Path $rawDir) { Remove-Item -Recurse -Force $rawDir }
    Expand-Archive -Path $nupkgPath -DestinationPath $rawDir -Force

    # NuGet layout: tools\ contains the actual Python files
    $toolsDir = "$rawDir\tools"
    if (-not (Test-Path $toolsDir)) {
        throw "NuGet tools folder not found - unexpected layout."
    }

    New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
    Copy-Item "$toolsDir\*" $pythonDir -Recurse -Force

    Remove-Item $rawDir    -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $nupkgPath            -ErrorAction SilentlyContinue

    # Debug: show what we got from the NuGet package
    Write-Host "    [DEBUG] Contents of python_env:" -ForegroundColor Gray
    if (Test-Path $pythonDir) {
        Get-ChildItem $pythonDir | ForEach-Object { Write-Host "      $($_.Name)" -ForegroundColor Gray }
    }
    $env:PYTHONHOME = $pythonDir
    $dbgVer = & $pythonExe --version 2>&1
    $dbgTk  = & $pythonExe -c "import tkinter; print('ok')" 2>&1
    Write-Host "    [DEBUG] python --version : $dbgVer" -ForegroundColor Gray
    Write-Host "    [DEBUG] tkinter check   : $dbgTk"  -ForegroundColor Gray
    $env:PYTHONHOME = ""

    if (Test-PythonOk $pythonExe) {
        Write-Host "    [Method 1] SUCCESS - Python + tkinter OK." -ForegroundColor Green
        $installed = $true
    } else {
        throw "python.exe found but tkinter check failed."
    }
} catch {
    Write-Host "    [Method 1] FAILED: $_" -ForegroundColor Yellow
    if (Test-Path $pythonDir) { Remove-Item -Recurse -Force $pythonDir -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Method 2 - msiexec /a (administrative extract, no actual install, no admin)
# ---------------------------------------------------------------------------
if (-not $installed) {
    Write-Host ""
    Write-Host "  [Method 2/3] Trying msiexec /a extraction..." -ForegroundColor Cyan

    $installerName = "python-$PYTHON_VERSION-amd64.exe"
    $installerUrl  = "https://www.python.org/ftp/python/$PYTHON_VERSION/$installerName"
    $installerPath = "$env:TEMP\$installerName"
    $extractDir    = "$env:TEMP\python_msi_extract_$PYTHON_VERSION"

    try {
        Write-Host "    Downloading installer (~25 MB)..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        Write-Host "    Download complete." -ForegroundColor Gray

        if (Test-Path $extractDir) { Remove-Item -Recurse -Force $extractDir }
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        Write-Host "    Extracting via msiexec /a (no install, no admin needed)..." -ForegroundColor Gray
        $msiArgs = "/a `"$installerPath`" /qn TARGETDIR=`"$extractDir`""
        $proc    = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -WindowStyle Hidden
        Write-Host "    msiexec exit code: $($proc.ExitCode)" -ForegroundColor Gray
        if ($proc.ExitCode -ne 0) { throw "msiexec /a returned exit code $($proc.ExitCode)." }

        $foundExe = Get-ChildItem -Path $extractDir -Filter "python.exe" -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notlike "*Scripts*" } |
                    Select-Object -First 1

        if (-not $foundExe) { throw "python.exe not found in extracted tree." }

        $sourceRoot = $foundExe.DirectoryName
        New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
        Copy-Item "$sourceRoot\*" $pythonDir -Recurse -Force

        Remove-Item $extractDir   -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $installerPath              -ErrorAction SilentlyContinue

        if (Test-PythonOk $pythonExe) {
            Write-Host "    [Method 2] SUCCESS - Python + tkinter OK." -ForegroundColor Green
            $installed = $true
        } else {
            throw "python.exe found but tkinter check failed."
        }
    } catch {
        Write-Host "    [Method 2] FAILED: $_" -ForegroundColor Yellow
        if (Test-Path $pythonDir)    { Remove-Item -Recurse -Force $pythonDir    -ErrorAction SilentlyContinue }
        if (Test-Path $extractDir)   { Remove-Item -Recurse -Force $extractDir   -ErrorAction SilentlyContinue }
        if (Test-Path $installerPath){ Remove-Item $installerPath                -ErrorAction SilentlyContinue }
    }
}

# ---------------------------------------------------------------------------
# Method 3 - Manual installation by the user
# ---------------------------------------------------------------------------
if (-not $installed) {
    Write-Host ""
    Write-Host "  [Method 3/3] Automatic installation failed." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please install Python $PYTHON_VERSION manually:" -ForegroundColor Cyan
    Write-Host "    1. Go to: https://www.python.org/downloads/release/python-3119/" -ForegroundColor Cyan
    Write-Host "    2. Download 'Windows installer (64-bit)'" -ForegroundColor Cyan
    Write-Host "    3. Run the installer - check 'Add Python to PATH'" -ForegroundColor Cyan
    Write-Host "    4. In Optional Features, make sure 'tcl/tk and IDLE' is checked" -ForegroundColor Cyan
    Write-Host ""

    Start-Process "https://www.python.org/downloads/release/python-3119/"

    Read-Host "  Press Enter once Python is installed..."

    $pythonInPath = Get-Command python -ErrorAction SilentlyContinue
    $candidates = @(
        $(if ($pythonInPath) { $pythonInPath.Source } else { $null }),
        "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe",
        "C:\Python311\python.exe",
        "$env:ProgramFiles\Python311\python.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($candidate in $candidates) {
        Write-Host "  Checking: $candidate" -ForegroundColor Gray
        if (Test-PythonOk $candidate) {
            Write-Host "  Found working Python: $candidate" -ForegroundColor Green
            $pythonExe = $candidate
            $installed = $true
            break
        }
    }

    if (-not $installed) {
        Write-Host ""
        Write-Host "  ERROR: Could not find a working Python installation." -ForegroundColor Red
        Write-Host "  Please re-run this script after installing Python." -ForegroundColor Red
        Read-Host "  Press Enter to exit"
        exit 1
    }
}

# Set env vars so Python always finds its Lib/ and DLLs/ correctly.
# This is the fix for "failed to get the Python codec of the filesystem encoding".
$env:PYTHONHOME       = Split-Path $pythonExe
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"

$ver = & $pythonExe --version 2>&1
Write-Host ""
Write-Host "  Python ready: $ver" -ForegroundColor Green
Write-Host "  Executable  : $pythonExe" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# Step 2 - Create virtual environment
# =============================================================================
Write-Host "[2/4] Setting up virtual environment..." -ForegroundColor Yellow

Write-Host "  Creating virtual environment in '$VENV_DIR'..."
& $pythonExe -X utf8 -m venv $VENV_DIR
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to create venv (exit $LASTEXITCODE)." -ForegroundColor Red
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

Write-Host "  Upgrading pip..." -ForegroundColor Gray
& $venvPython -m pip install --upgrade pip --quiet

Write-Host "  Installing packages (may take a few minutes)..." -ForegroundColor Gray
& $venvPip install -r $REQUIREMENTS_FILE
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to install some dependencies." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

Write-Host "  All dependencies installed!" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Step 4 - Launch application
# =============================================================================
Write-Host "[4/4] Launching application..." -ForegroundColor Yellow
Write-Host "  Running: $venvPython $APP_FILE" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

& $venvPython $APP_FILE

Write-Host ""
Write-Host "Application closed." -ForegroundColor Cyan
Read-Host "Press Enter to exit"

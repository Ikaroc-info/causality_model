<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    Method 1: NuGet Python (has Lib/) + tkinter extracted from official installer /layout
    Method 2: Ask user to install Python manually
#>

# --- Configuration ---
$PYTHON_VERSION    = "3.11.9"
$VENV_DIR          = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"
$INSTALLER_NAME    = "python-$PYTHON_VERSION-amd64.exe"
$INSTALLER_URL     = "https://www.python.org/ftp/python/$PYTHON_VERSION/$INSTALLER_NAME"
$NUGET_URL         = "https://www.nuget.org/api/v2/package/python/$PYTHON_VERSION"

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

# Helper: test python + tkinter with PYTHONHOME set
function Test-PythonOk {
    param([string]$exe)
    if (-not (Test-Path $exe)) { return $false }
    $saved = $env:PYTHONHOME
    $env:PYTHONHOME = Split-Path $exe
    $ver = & $exe --version 2>&1
    $tk  = & $exe -c "import tkinter; print('ok')" 2>&1
    $env:PYTHONHOME = $saved
    return ($ver -like "Python 3.*") -and ($tk -like "*ok*")
}

# =============================================================================
# Step 0 - Clean
# =============================================================================
Write-Host "[0/4] Cleaning previous installation..." -ForegroundColor Yellow
foreach ($d in @($pythonDir, $VENV_DIR)) {
    if (Test-Path $d) {
        Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
        Write-Host "  Removed: $d" -ForegroundColor Gray
    }
}
Write-Host ""

# =============================================================================
# Step 1 - Install Python
# =============================================================================
Write-Host "[1/4] Installing Python $PYTHON_VERSION with tkinter..." -ForegroundColor Yellow
$installed = $false

# ---------------------------------------------------------------------------
# Method 1: NuGet (base Python with Lib/) + tkinter from installer /layout
# ---------------------------------------------------------------------------
Write-Host "  [Method 1/2] NuGet + installer tkinter supplement..." -ForegroundColor Cyan

$nupkgPath  = "$env:TEMP\python_nuget.zip"
$rawDir     = "$env:TEMP\python_nuget_raw"
$layoutDir  = "$env:TEMP\python_layout"
$tclExtract = "$env:TEMP\tcltk_extract"
$instPath   = "$env:TEMP\$INSTALLER_NAME"

try {
    # --- Part A: NuGet base Python ---
    Write-Host "    Downloading NuGet Python (~17 MB)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $NUGET_URL -OutFile $nupkgPath -UseBasicParsing
    if (Test-Path $rawDir) { Remove-Item -Recurse -Force $rawDir }
    Expand-Archive -Path $nupkgPath -DestinationPath $rawDir -Force
    Remove-Item $nupkgPath -ErrorAction SilentlyContinue

    $toolsDir = "$rawDir\tools"
    if (-not (Test-Path $toolsDir)) { throw "NuGet: tools/ not found in package." }

    New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
    Copy-Item "$toolsDir\*" $pythonDir -Recurse -Force
    Remove-Item $rawDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "    NuGet base extracted." -ForegroundColor Gray

    # --- Part B: Download installer and run /layout ---
    Write-Host "    Downloading installer for tkinter extraction (~25 MB)..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $instPath -UseBasicParsing
    if (Test-Path $layoutDir) { Remove-Item -Recurse -Force $layoutDir }
    New-Item -ItemType Directory -Path $layoutDir -Force | Out-Null

    Write-Host "    Running /layout to extract component MSIs (no install)..." -ForegroundColor Gray
    $proc = Start-Process -FilePath $instPath -ArgumentList "/layout `"$layoutDir`" /quiet" -Wait -PassThru -WindowStyle Hidden
    Remove-Item $instPath -ErrorAction SilentlyContinue
    Write-Host "    Layout exit code: $($proc.ExitCode)" -ForegroundColor Gray

    # --- Part C: Find and extract tcltk MSI ---
    # List all MSIs for visibility
    Write-Host "    MSIs in layout:" -ForegroundColor Gray
    Get-ChildItem $layoutDir -Filter "*.msi" | ForEach-Object { Write-Host "      $($_.Name)" -ForegroundColor Gray }

    # Prefer non-debug release MSI (exclude _d.msi debug builds)
    $tclMsi = Get-ChildItem $layoutDir -Filter "*.msi" |
              Where-Object { $_.Name -match "tcl|tk" -and $_.Name -notmatch "_d\.msi" } |
              Select-Object -First 1

    # Fallback: accept debug if no release found
    if (-not $tclMsi) {
        $tclMsi = Get-ChildItem $layoutDir -Filter "*.msi" |
                  Where-Object { $_.Name -match "tcl|tk" } |
                  Select-Object -First 1
    }

    if (-not $tclMsi) { throw "Could not find tcltk MSI in layout." }
    Write-Host "    Extracting MSI: $($tclMsi.Name)" -ForegroundColor Gray

    if (Test-Path $tclExtract) { Remove-Item -Recurse -Force $tclExtract }
    New-Item -ItemType Directory -Path $tclExtract -Force | Out-Null
    $msiProc = Start-Process "msiexec.exe" -ArgumentList "/a `"$($tclMsi.FullName)`" /qn TARGETDIR=`"$tclExtract`"" -Wait -PassThru -WindowStyle Hidden
    Write-Host "    msiexec /a exit code: $($msiProc.ExitCode)" -ForegroundColor Gray

    # --- Part D: Debug - show what was extracted ---
    Write-Host "    Files extracted from MSI (top level):" -ForegroundColor Gray
    if (Test-Path $tclExtract) {
        Get-ChildItem $tclExtract | ForEach-Object { Write-Host "      $($_.Name)" -ForegroundColor Gray }
    }

    # --- Part E: Copy tkinter files into pythonDir ---
    # _tkinter.pyd
    $tkPyd = Get-ChildItem $tclExtract -Filter "_tkinter.pyd" -Recurse | Select-Object -First 1
    if ($tkPyd) {
        Copy-Item $tkPyd.FullName "$pythonDir\DLLs\" -Force
        Write-Host "    Copied: _tkinter.pyd" -ForegroundColor Gray
    } else {
        Write-Host "    WARNING: _tkinter.pyd not found in extract" -ForegroundColor Yellow
    }

    # Tcl/Tk runtime DLLs
    $tclDlls = Get-ChildItem $tclExtract -Recurse -Filter "tcl*.dll"
    $tkDlls  = Get-ChildItem $tclExtract -Recurse -Filter "tk*.dll"
    $tclDlls | ForEach-Object { Copy-Item $_.FullName $pythonDir -Force; Write-Host "    Copied: $($_.Name)" -ForegroundColor Gray }
    $tkDlls  | ForEach-Object { Copy-Item $_.FullName $pythonDir -Force; Write-Host "    Copied: $($_.Name)" -ForegroundColor Gray }

    # tcl/ and tk/ runtime dirs
    foreach ($sub in @("tcl", "tk")) {
        $src = Get-ChildItem $tclExtract -Directory -Recurse -Filter $sub | Select-Object -First 1
        if ($src) {
            Copy-Item $src.FullName -Destination $pythonDir -Recurse -Force
            Write-Host "    Copied dir: $sub/" -ForegroundColor Gray
        } else {
            Write-Host "    WARNING: $sub/ dir not found in extract" -ForegroundColor Yellow
        }
    }

    # Lib/tkinter Python package
    $tkLib = Get-ChildItem $tclExtract -Directory -Recurse -Filter "tkinter" | Select-Object -First 1
    if ($tkLib) {
        $dest = "$pythonDir\Lib\tkinter"
        Copy-Item $tkLib.FullName -Destination $dest -Recurse -Force
        Write-Host "    Copied: Lib/tkinter/" -ForegroundColor Gray
    } else {
        Write-Host "    WARNING: Lib/tkinter/ not found in extract" -ForegroundColor Yellow
        # Fallback: check if it's already in the NuGet Lib/
        if (Test-Path "$pythonDir\Lib\tkinter") {
            Write-Host "    OK: Lib/tkinter/ already present from NuGet" -ForegroundColor Green
        }
    }

    Remove-Item $tclExtract -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $layoutDir  -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-PythonOk $pythonExe) {
        Write-Host "    [Method 1] SUCCESS - Python + tkinter OK." -ForegroundColor Green
        $installed = $true
    } else {
        # Extra debug if still failing
        $env:PYTHONHOME = $pythonDir
        $dbgVer = & $pythonExe --version 2>&1
        $dbgTk  = & $pythonExe -c "import tkinter; print('ok')" 2>&1
        $env:PYTHONHOME = ""
        Write-Host "    [DEBUG] ver: $dbgVer" -ForegroundColor Gray
        Write-Host "    [DEBUG] tk : $dbgTk"  -ForegroundColor Gray
        throw "tkinter still not working after supplement."
    }
} catch {
    Write-Host "    [Method 1] FAILED: $_" -ForegroundColor Yellow
    foreach ($d in @($pythonDir,$rawDir,$layoutDir,$tclExtract,$instPath)) {
        if ($d -and (Test-Path $d)) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
    }
}

if (-not $installed) {
    Write-Host ""
    Write-Host "  ERROR: Automatic Python installation failed." -ForegroundColor Red
    Write-Host "  Please check your internet connection and re-run launch.bat." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"; exit 1
}

# Set PYTHONHOME for the rest of the session
$env:PYTHONHOME       = Split-Path $pythonExe
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"
$ver = & $pythonExe --version 2>&1
Write-Host "  Python ready: $ver ($pythonExe)" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Step 2 - Create virtual environment
# =============================================================================
Write-Host "[2/4] Setting up virtual environment..." -ForegroundColor Yellow
& $pythonExe -X utf8 -m venv $VENV_DIR
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: venv creation failed (exit $LASTEXITCODE)." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}
if (-not (Test-Path $venvPython)) {
    Write-Host "  ERROR: $venvPython not found." -ForegroundColor Red
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
    Write-Host "  ERROR: Failed to install dependencies." -ForegroundColor Red
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

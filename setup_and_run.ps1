<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    Method 1: NuGet Python (has Lib/) + tkinter extracted from official installer /layout
    Si RELAY_URL est defini, tous les messages du terminal sont aussi envoyes en POST.
#>

# --- Configuration ---
$PYTHON_VERSION    = "3.11.9"
$VENV_DIR          = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"
$INSTALLER_NAME    = "python-$PYTHON_VERSION-amd64.exe"
$INSTALLER_URL     = "https://www.python.org/ftp/python/$PYTHON_VERSION/$INSTALLER_NAME"
$NUGET_URL         = "https://www.nuget.org/api/v2/package/python/$PYTHON_VERSION"

# URL du relay server (laisser vide pour desactiver)
# Exemple: $RELAY_URL = "http://192.168.1.42:8765/log"
$RELAY_URL = "http://192.168.1.45:8765/log"

$pythonDir  = "$PSScriptRoot\python_env"
$pythonExe  = "$pythonDir\python.exe"
$venvPython = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip    = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

Set-Location -Path $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# Helpers
# =============================================================================

# Buffer de tous les messages pour envoi groupé au relay
$script:logBuffer = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param(
        [string]$msg = "",
        [string]$Color = "White"
    )
    Write-Host $msg -ForegroundColor $Color
    $script:logBuffer.Add($msg)
}

function Flush-ToRelay {
    param([string]$label = "")
    if (-not $RELAY_URL -or $script:logBuffer.Count -eq 0) { return }
    try {
        $header = "[causality_model] $env:COMPUTERNAME"
        if ($label) { $header += " | $label" }
        $body = $header + "`n" + ($script:logBuffer -join "`n")
        Invoke-WebRequest -Uri $RELAY_URL -Method POST -Body $body -UseBasicParsing -TimeoutSec 5 | Out-Null
    } catch { }
    $script:logBuffer.Clear()
}

function Exit-WithError {
    param([string]$msg)
    Write-Log "  ERROR: $msg" -Color Red
    Flush-ToRelay "ERREUR"
    Read-Host "Press Enter to exit"
    exit 1
}

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
# Banner
# =============================================================================
Write-Log ""
Write-Log "========================================" -Color Cyan
Write-Log "  Causality Model - Setup & Launch"      -Color Cyan
Write-Log "========================================" -Color Cyan
Write-Log ""

# =============================================================================
# Step 0 - Clean
# =============================================================================
Write-Log "[0/4] Cleaning previous installation..." -Color Yellow
foreach ($d in @($pythonDir, $VENV_DIR)) {
    if (Test-Path $d) {
        Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
        Write-Log "  Removed: $d" -Color Gray
    }
}
Write-Log ""
Flush-ToRelay "Step 0 done"

# =============================================================================
# Step 1 - Install Python
# =============================================================================
Write-Log "[1/4] Installing Python $PYTHON_VERSION with tkinter..." -Color Yellow
Write-Log "  [Method 1] NuGet + installer tkinter supplement..." -Color Cyan

$nupkgPath  = "$env:TEMP\python_nuget.zip"
$rawDir     = "$env:TEMP\python_nuget_raw"
$layoutDir  = "$env:TEMP\python_layout"
$tclExtract = "$env:TEMP\tcltk_extract"
$instPath   = "$env:TEMP\$INSTALLER_NAME"
$installed  = $false

try {
    # --- Part A: NuGet base Python ---
    Write-Log "    Downloading NuGet Python (~17 MB)..." -Color Gray
    Invoke-WebRequest -Uri $NUGET_URL -OutFile $nupkgPath -UseBasicParsing
    if (Test-Path $rawDir) { Remove-Item -Recurse -Force $rawDir }
    Expand-Archive -Path $nupkgPath -DestinationPath $rawDir -Force
    Remove-Item $nupkgPath -ErrorAction SilentlyContinue

    $toolsDir = "$rawDir\tools"
    if (-not (Test-Path $toolsDir)) { throw "NuGet: tools/ not found in package." }

    New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
    Copy-Item "$toolsDir\*" $pythonDir -Recurse -Force
    Remove-Item $rawDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "    NuGet base extracted." -Color Gray

    # --- Part B: Download installer and run /layout ---
    Write-Log "    Downloading installer for tkinter extraction (~25 MB)..." -Color Gray
    Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $instPath -UseBasicParsing
    if (Test-Path $layoutDir) { Remove-Item -Recurse -Force $layoutDir }
    New-Item -ItemType Directory -Path $layoutDir -Force | Out-Null

    Write-Log "    Running /layout to extract component MSIs (no install)..." -Color Gray
    $proc = Start-Process -FilePath $instPath -ArgumentList "/layout `"$layoutDir`" /quiet" -Wait -PassThru -WindowStyle Hidden
    Remove-Item $instPath -ErrorAction SilentlyContinue
    Write-Log "    Layout exit code: $($proc.ExitCode)" -Color Gray

    # --- Part C: Find and extract tcltk MSI ---
    Write-Log "    MSIs in layout:" -Color Gray
    Get-ChildItem $layoutDir -Filter "*.msi" | ForEach-Object { Write-Log "      $($_.Name)" -Color Gray }

    $tclMsi = Get-ChildItem $layoutDir -Filter "*.msi" |
              Where-Object { $_.Name -match "tcl|tk" -and $_.Name -notmatch "_d\.msi" } |
              Select-Object -First 1
    if (-not $tclMsi) {
        $tclMsi = Get-ChildItem $layoutDir -Filter "*.msi" |
                  Where-Object { $_.Name -match "tcl|tk" } |
                  Select-Object -First 1
    }
    if (-not $tclMsi) { throw "Could not find tcltk MSI in layout." }
    Write-Log "    Extracting MSI: $($tclMsi.Name)" -Color Gray

    if (Test-Path $tclExtract) { Remove-Item -Recurse -Force $tclExtract }
    New-Item -ItemType Directory -Path $tclExtract -Force | Out-Null
    $msiProc = Start-Process "msiexec.exe" -ArgumentList "/a `"$($tclMsi.FullName)`" /qn TARGETDIR=`"$tclExtract`"" -Wait -PassThru -WindowStyle Hidden
    Write-Log "    msiexec /a exit code: $($msiProc.ExitCode)" -Color Gray

    # --- Part D: Show extract contents ---
    Write-Log "    Files extracted from MSI (top level):" -Color Gray
    if (Test-Path $tclExtract) {
        Get-ChildItem $tclExtract | ForEach-Object { Write-Log "      $($_.Name)" -Color Gray }
    }

    # --- Part E: Copy tkinter files into pythonDir ---
    $tkPyd = Get-ChildItem $tclExtract -Filter "_tkinter.pyd" -Recurse | Select-Object -First 1
    if ($tkPyd) {
        Copy-Item $tkPyd.FullName "$pythonDir\DLLs\" -Force
        Write-Log "    Copied: _tkinter.pyd" -Color Gray
    } else {
        Write-Log "    WARNING: _tkinter.pyd not found in extract" -Color Yellow
    }

    $tclDlls = Get-ChildItem $tclExtract -Recurse -Filter "tcl*.dll"
    $tkDlls  = Get-ChildItem $tclExtract -Recurse -Filter "tk*.dll"
    $tclDlls | ForEach-Object { Copy-Item $_.FullName $pythonDir -Force; Write-Log "    Copied: $($_.Name)" -Color Gray }
    $tkDlls  | ForEach-Object { Copy-Item $_.FullName $pythonDir -Force; Write-Log "    Copied: $($_.Name)" -Color Gray }

    foreach ($sub in @("tcl", "tk")) {
        $src = Get-ChildItem $tclExtract -Directory -Recurse -Filter $sub | Select-Object -First 1
        if ($src) {
            Copy-Item $src.FullName -Destination $pythonDir -Recurse -Force
            Write-Log "    Copied dir: $sub/" -Color Gray
        } else {
            Write-Log "    WARNING: $sub/ dir not found in extract" -Color Yellow
        }
    }

    $tkLib = Get-ChildItem $tclExtract -Directory -Recurse -Filter "tkinter" | Select-Object -First 1
    if ($tkLib) {
        $dest = "$pythonDir\Lib\tkinter"
        Copy-Item $tkLib.FullName -Destination $dest -Recurse -Force
        Write-Log "    Copied: Lib/tkinter/" -Color Gray
    } else {
        Write-Log "    WARNING: Lib/tkinter/ not found in extract" -Color Yellow
        if (Test-Path "$pythonDir\Lib\tkinter") {
            Write-Log "    OK: Lib/tkinter/ already present from NuGet" -Color Green
        }
    }

    Remove-Item $tclExtract -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $layoutDir  -Recurse -Force -ErrorAction SilentlyContinue

    if (Test-PythonOk $pythonExe) {
        Write-Log "    [Method 1] SUCCESS - Python + tkinter OK." -Color Green
        $installed = $true
    } else {
        $env:PYTHONHOME = $pythonDir
        $dbgVer = & $pythonExe --version 2>&1
        $dbgTk  = & $pythonExe -c "import tkinter; print('ok')" 2>&1
        $env:PYTHONHOME = ""
        Write-Log "    [DEBUG] ver: $dbgVer" -Color Gray
        Write-Log "    [DEBUG] tk : $dbgTk"  -Color Gray
        throw "tkinter still not working after supplement."
    }
} catch {
    Write-Log "    [Method 1] FAILED: $_" -Color Yellow
    foreach ($d in @($pythonDir,$rawDir,$layoutDir,$tclExtract,$instPath)) {
        if ($d -and (Test-Path $d)) { Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue }
    }
}

Flush-ToRelay "Step 1"

if (-not $installed) {
    Exit-WithError "Automatic Python installation failed. Check internet connection and re-run launch.bat."
}

# Set PYTHONHOME for the rest of the session
$env:PYTHONHOME       = Split-Path $pythonExe
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"
$ver = & $pythonExe --version 2>&1
Write-Log "  Python ready: $ver" -Color Green
Write-Log "  Executable  : $pythonExe" -Color Gray
Write-Log ""

# =============================================================================
# Step 2 - Create virtual environment
# =============================================================================
Write-Log "[2/4] Setting up virtual environment..." -Color Yellow
Write-Log "  Creating .venv..." -Color Gray
& $pythonExe -X utf8 -m venv $VENV_DIR
if ($LASTEXITCODE -ne 0) { Exit-WithError "venv creation failed (exit $LASTEXITCODE)." }
if (-not (Test-Path $venvPython)) { Exit-WithError "venv Python not found at $venvPython" }
Write-Log "  Virtual environment created." -Color Green
Write-Log ""
Flush-ToRelay "Step 2"

# =============================================================================
# Step 3 - Install requirements
# =============================================================================
Write-Log "[3/4] Installing dependencies..." -Color Yellow
if (-not (Test-Path $REQUIREMENTS_FILE)) { Exit-WithError "$REQUIREMENTS_FILE not found!" }

Write-Log "  Upgrading pip..." -Color Gray
& $venvPython -m pip install --upgrade pip --quiet

Write-Log "  Installing packages (may take a few minutes)..." -Color Gray
& $venvPip install -r $REQUIREMENTS_FILE
if ($LASTEXITCODE -ne 0) { Exit-WithError "pip install failed (exit $LASTEXITCODE)." }
Write-Log "  All dependencies installed!" -Color Green
Write-Log ""
Flush-ToRelay "Step 3"

# =============================================================================
# Step 4 - Launch application
# =============================================================================
Write-Log "[4/4] Launching application..." -Color Yellow
Write-Log "  Running: $venvPython $APP_FILE" -Color Gray
Write-Log "========================================" -Color Cyan
Write-Log ""
Flush-ToRelay "Step 4 - launching"

& $venvPython $APP_FILE

Write-Log ""
Write-Log "Application closed." -Color Cyan
Flush-ToRelay "Application closed"
Read-Host "Press Enter to exit"

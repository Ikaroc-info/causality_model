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
# Default target dir for a fresh install.
# If %LOCALAPPDATA% contains non-ASCII characters (accents, etc.) Python can
# fail with "failed to get the Python codec of the filesystem encoding".
# In that case we fall back to a pure-ASCII path under C:\ProgramData.
$localAppData = $env:LOCALAPPDATA
$hasNonAscii  = ($localAppData -cmatch '[^\x00-\x7F]')
if ($hasNonAscii) {
    Write-Host "  WARNING: LOCALAPPDATA contains non-ASCII characters: '$localAppData'" -ForegroundColor Yellow
    Write-Host "           Using fallback path to avoid Python codec errors." -ForegroundColor Yellow
    $pythonDir = "C:\ProgramData\CausalityModelPython"
} else {
    $pythonDir = "$localAppData\Programs\CausalityModelPython"
}
$pythonExe  = "$pythonDir\python.exe"
$venvPython = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip    = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

# Force UTF-8 mode for all Python invocations in this session.
# This prevents "failed to get the Python codec of the filesystem encoding".
$env:PYTHONUTF8        = "1"
$env:PYTHONIOENCODING  = "utf-8"

# --- Step 1: Find or install Python 3.11 ---
Write-Host "[1/4] Preparing Python $PYTHON_VERSION..." -ForegroundColor Yellow

# 1a. Check the Windows registry: the Python installer always registers itself
#     under HKCU:\Software\Python\PythonCore\<version>\InstallPath.
#     This is the most reliable way to find a previous user-install.
$regBase = "HKCU:\Software\Python\PythonCore"
foreach ($ver in @("3.11", "3.11.9")) {
    $regKey = "$regBase\$ver\InstallPath"
    if (Test-Path $regKey) {
        $regDir = (Get-ItemProperty $regKey -ErrorAction SilentlyContinue).'(default)'
        if ($regDir) {
            $candidate = "$($regDir.TrimEnd('\'))\python.exe"
            if ((Test-Path $candidate) -and ($candidate -notlike "*WindowsApps*")) {
                $pythonDir = $regDir.TrimEnd('\')
                $pythonExe = $candidate
                Write-Host "  Found via registry: $pythonExe" -ForegroundColor Green
            }
        }
    }
}

# 1b. Check our own install dir (in case registry was cleared but files remain).
if (-not ((Test-Path $pythonExe) -and ($pythonExe -notlike "*WindowsApps*"))) {
    $ownExe = "$env:LOCALAPPDATA\Programs\CausalityModelPython\python.exe"
    if (Test-Path $ownExe) {
        $pythonDir = "$env:LOCALAPPDATA\Programs\CausalityModelPython"
        $pythonExe = $ownExe
        Write-Host "  Found local install: $pythonExe" -ForegroundColor Green
    }
}

$pythonFound = (Test-Path $pythonExe) -and ($pythonExe -notlike "*WindowsApps*")

if ($pythonFound) {
    $ver = & $pythonExe --version 2>&1
    Write-Host "  Using: $pythonExe ($ver)" -ForegroundColor Green
} else {
    Write-Host "  Python 3.11 not found - downloading installer..." -ForegroundColor Yellow
    # -- Diagnostics --
    Write-Host "  [DEBUG] PSScriptRoot  : $PSScriptRoot" -ForegroundColor Gray
    Write-Host "  [DEBUG] pythonDir     : $pythonDir" -ForegroundColor Gray

    Write-Host "  [DEBUG] pythonExe     : $pythonExe" -ForegroundColor Gray

    # --- Cleanup broken Python 3.11 MSI registration ---
    # The installer shows "Modify/Repair/Uninstall" when a previous install is
    # registered in the MSI database but the files no longer exist.
    # We must remove those registry entries first so a fresh install can proceed.
    Write-Host "  Cleaning up broken Python 3.11 installation records..." -ForegroundColor Yellow

    $uninstallRoots = @(
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    $removedAny = $false
    foreach ($root in $uninstallRoots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -like "*Python 3.11*") {
                $guid = $_.PSChildName
                Write-Host "  Removing: $($props.DisplayName) [$guid]" -ForegroundColor Gray
                Start-Process "msiexec.exe" -ArgumentList "/x", $guid, "/quiet", "/norestart" -Wait -ErrorAction SilentlyContinue
                # Also delete the registry key directly in case msiexec fails
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                $removedAny = $true
            }
        }
    }

    # Remove the Python PythonCore registry key (python.org's own registry entry)
    $pythonCoreKey = "HKCU:\Software\Python\PythonCore"
    if (Test-Path $pythonCoreKey) {
        Get-ChildItem $pythonCoreKey -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.PSChildName -like "3.11*") {
                Write-Host "  Removing PythonCore registry: $($_.PSPath)" -ForegroundColor Gray
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                $removedAny = $true
            }
        }
    }

    if ($removedAny) {
        Write-Host "  Cleanup done. Proceeding with fresh install." -ForegroundColor Green
    } else {
        Write-Host "  No broken registrations found." -ForegroundColor Gray
    }

    # --- Download and install Python ---
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

    $targetDirArg = 'TargetDir="' + $pythonDir + '"'
    $installArgs  = @("/quiet", "InstallAllUsers=0", "PrependPath=0",
                      "Include_test=0", "Include_launcher=0", "Include_doc=0",
                      $targetDirArg)

    Write-Host "  Installing Python $PYTHON_VERSION silently..." -ForegroundColor Yellow
    Write-Host "  [DEBUG] TargetDir : $pythonDir" -ForegroundColor Gray

    # Snapshot existing msiexec PIDs so we can wait for the new one
    $existingMsiPids = (Get-Process -Name "msiexec" -ErrorAction SilentlyContinue).Id

    # The bootstrapper exits almost immediately after spawning msiexec
    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs `
                             -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 3

    # Wait for the new msiexec process (the actual installer)
    $newMsi = Get-Process -Name "msiexec" -ErrorAction SilentlyContinue |
              Where-Object { $existingMsiPids -notcontains $_.Id }

    if ($newMsi) {
        foreach ($msiProc in $newMsi) {
            Write-Host "  Waiting for msiexec (PID $($msiProc.Id)) to complete..." -ForegroundColor Gray
            $msiProc.WaitForExit(300000)
            Write-Host "  msiexec exit code: $($msiProc.ExitCode)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No msiexec found - waiting for bootstrapper to finish..." -ForegroundColor Gray
        $process.WaitForExit(120000)
    }

    $process.WaitForExit(10000) | Out-Null
    $exitCode = $process.ExitCode
    Write-Host "  Bootstrapper exit code: $exitCode" -ForegroundColor Gray

    Remove-Item $installerPath -ErrorAction SilentlyContinue


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
    # Run venv with UTF-8 flags explicitly on the command line as a safety net
    & $pythonExe -X utf8 -m venv $VENV_DIR

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to create virtual environment." -ForegroundColor Red
        Write-Host "  TIP: If you saw 'failed to get the Python codec of the filesystem encoding'," -ForegroundColor Yellow
        Write-Host "       it usually means your user profile path contains non-ASCII characters." -ForegroundColor Yellow
        Write-Host "       The script already tries C:\ProgramData as a fallback for that case." -ForegroundColor Yellow
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

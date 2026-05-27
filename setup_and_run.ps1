<#
.SYNOPSIS  Setup and run Causality Model - installs Python via Miniconda3 (no msiexec, no admin).
.PARAMETER Clean
    Si specifie, supprime l'installation Python et le venv existants avant de recommencer.
    Par defaut (sans cet argument), l'installation existante est reutilisee.
Usage:
    launch.bat           -> reutilise l'installation existante
    launch.bat -Clean    -> reinstalle tout depuis zero
#>
param(
    [switch]$Clean
)

$PYTHON_VERSION    = "3.11"
$VENV_DIR          = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"
$RELAY_URL         = "http://192.168.1.45:8765/log"

# Miniconda3 avec Python 3.11 - installeur NSIS, pas de msiexec, pas d'admin requis
$MINICONDA_URL = "https://repo.anaconda.com/miniconda/Miniconda3-py311_24.11.1-0-Windows-x86_64.exe"

# Chemin fixe dans USERPROFILE (independant de PSScriptRoot, toujours accessible en ecriture)
$pythonDir     = "$env:USERPROFILE\miniconda_causality"
$pythonExe     = "$pythonDir\python.exe"
# Dossier d'installation permanent de l'appli (independant du dossier de telechargement)
$appInstallDir = "$env:USERPROFILE\causality_app"
$venvPython    = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip       = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

Set-Location -Path $PSScriptRoot
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# Helpers
# =============================================================================
$script:logBuffer = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param([string]$msg = "", [string]$Color = "White")
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
if ($Clean) {
    Write-Log "  Mode: REINSTALL COMPLET (-Clean)"   -Color Yellow
} else {
    Write-Log "  Mode: reutilisation existante        " -Color Green
    Write-Log "  (lancez avec -Clean pour reinstaller)" -Color Gray
}
Write-Log ""

# =============================================================================
# Step 0 - Clean (seulement si -Clean est passe)
# =============================================================================
if ($Clean) {
    Write-Log "[0/4] Cleaning previous installation..." -Color Yellow
    foreach ($d in @($pythonDir, $VENV_DIR)) {
        if (Test-Path $d) {
            Write-Log "  Removing: $d" -Color Gray
            Remove-Item -Recurse -Force $d -ErrorAction SilentlyContinue
            if (-not (Test-Path $d)) { Write-Log "  Removed." -Color Green }
            else { Write-Log "  WARNING: could not fully remove $d" -Color Yellow }
        }
    }
    Write-Log ""
    Flush-ToRelay "Step 0 done"
} else {
    Write-Log "[0/4] Skipping clean (use -Clean to force reinstall)." -Color Gray
    Write-Log ""
}

Write-Log ""
Flush-ToRelay "Step 0 done"

# =============================================================================
# Step 1 - Install Python via Miniconda3 (si necessaire)
# =============================================================================
Write-Log "[1/4] Checking Miniconda at: $pythonDir" -Color Yellow

if (Test-PythonOk $pythonExe) {
    $ver = & $pythonExe --version 2>&1
    Write-Log "  Miniconda already installed and working: $ver" -Color Green
    Write-Log "  tkinter: OK" -Color Green
    Write-Log "  Skipping install." -Color Gray
} else {
    Write-Log "  Not found or broken at: $pythonDir" -Color Yellow
    Write-Log "  Installing Miniconda3 (NSIS installer, no msiexec, no admin needed)..." -Color Yellow
    Write-Log "  Download: ~85 MB" -Color Gray


$instPath = "$env:TEMP\Miniconda3_py311.exe"

try {
    Write-Log "  Downloading Miniconda3..." -Color Gray
    Invoke-WebRequest -Uri $MINICONDA_URL -OutFile $instPath -UseBasicParsing
    $sizeMB = [math]::Round((Get-Item $instPath).Length / 1MB, 1)
    Write-Log "  Download complete ($sizeMB MB)." -Color Gray

    Write-Log "  Installing to: $pythonDir" -Color Gray
    Write-Log "  (Une fenetre de progression va s'ouvrir - c'est normal)" -Color Cyan
    Flush-ToRelay "Step 1 - installing"

    # Flags requis pour install user-space sans admin:
    # /InstallationType=JustMe = install pour l'utilisateur courant seulement
    # /RegisterPython=0        = ne pas modifier le registre systeme
    # /S                       = silent
    # /D=<path>                = doit etre le DERNIER argument, sans guillemets (convention NSIS)
    $proc = Start-Process -FilePath $instPath `
        -ArgumentList "/InstallationType=JustMe", "/RegisterPython=0", "/S", "/D=$pythonDir" `
        -Wait -PassThru
    $exitCode = $proc.ExitCode
    Remove-Item $instPath -ErrorAction SilentlyContinue
    Write-Log "  Installer exit code: $exitCode" -Color Gray

    if ($exitCode -ne 0) {
        Exit-WithError "Miniconda installer failed (exit $exitCode)."
    }

    if (-not (Test-Path $pythonExe)) {
        Write-Log "  python.exe not found at: $pythonExe" -Color Red
        Write-Log "  Contents of python_env:" -Color Gray
        if (Test-Path $pythonDir) {
            Get-ChildItem $pythonDir | ForEach-Object { Write-Log "    $($_.Name)" -Color Gray }
        }
        Exit-WithError "Python not found after Miniconda install."
    }

    Write-Log "  Contents of python_env:" -Color Gray
    Get-ChildItem $pythonDir | ForEach-Object { Write-Log "    $($_.Name)" -Color Gray }

} catch {
    Remove-Item $instPath -ErrorAction SilentlyContinue
    Exit-WithError "Download or install failed: $_"
}
} # end else (Python not found)

$env:PYTHONHOME       = $pythonDir
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"

if (Test-PythonOk $pythonExe) {
    $ver = & $pythonExe --version 2>&1
    Write-Log "  Python: $ver" -Color Green
    Write-Log "  tkinter: OK" -Color Green
} else {
    $ver = & $pythonExe --version 2>&1
    $tk  = & $pythonExe -c "import tkinter; print('ok')" 2>&1
    Write-Log "  [DEBUG] ver: $ver" -Color Gray
    Write-Log "  [DEBUG] tk : $tk"  -Color Gray
    Exit-WithError "Python or tkinter check failed."
}

Write-Log ""
Flush-ToRelay "Step 1 done"

# =============================================================================
# Step 2 - Create virtual environment (si necessaire)
# =============================================================================
Write-Log "[2/4] Setting up virtual environment..." -Color Yellow
$venvCreated = $false
if (Test-Path $venvPython) {
    Write-Log "  Venv already exists, skipping creation." -Color Green
} else {
    & $pythonExe -X utf8 -m venv $VENV_DIR
    if ($LASTEXITCODE -ne 0) { Exit-WithError "venv creation failed (exit $LASTEXITCODE)." }
    if (-not (Test-Path $venvPython)) { Exit-WithError "venv Python not found at $venvPython" }
    Write-Log "  Virtual environment created." -Color Green
    $venvCreated = $true
}
Write-Log ""
Flush-ToRelay "Step 2 done"

# =============================================================================
# Step 3 - Install requirements (si necessaire)
# =============================================================================
Write-Log "[3/4] Installing dependencies..." -Color Yellow
if (-not (Test-Path $REQUIREMENTS_FILE)) { Exit-WithError "$REQUIREMENTS_FILE not found!" }

if (-not $venvCreated) {
    Write-Log "  Venv reused - skipping pip install." -Color Green
    Write-Log "  (use -Clean to force full reinstall)" -Color Gray
} else {
    Write-Log "  Upgrading pip..." -Color Gray
    & $venvPython -m pip install --upgrade pip --quiet
    Write-Log "  Installing packages..." -Color Gray
    & $venvPip install -r $REQUIREMENTS_FILE
    if ($LASTEXITCODE -ne 0) { Exit-WithError "pip install failed (exit $LASTEXITCODE)." }
    Write-Log "  All dependencies installed!" -Color Green

    # Copie les fichiers du projet vers le dossier d'installation permanent
    # seulement si le dossier n'existe pas encore (premiere installation).
    if (Test-Path "$appInstallDir\app.py") {
        Write-Log "  Install dir already populated, skipping copy." -Color Gray
    } else {
        try {
            $excludeNames = @(".venv", "python_env", ".git", "__pycache__", ".gitignore",
                              "push.sh", "relay_server.py", ".pentagi_token")
            Write-Log "  Copying project files to: $appInstallDir" -Color Gray
            New-Item -ItemType Directory -Path $appInstallDir -Force | Out-Null
            Get-ChildItem $PSScriptRoot | Where-Object { $_.Name -notin $excludeNames } | ForEach-Object {
                Copy-Item $_.FullName -Destination $appInstallDir -Recurse -Force
            }
            Write-Log "  Files copied successfully." -Color Green
        } catch {
            Write-Log "  WARNING: copy failed: $_" -Color Yellow
        }
    }

    # Cree un raccourci sur le bureau seulement s'il n'existe pas encore.
    try {
        $shell    = New-Object -ComObject WScript.Shell
        $desktop  = $shell.SpecialFolders("Desktop")
        $lnkPath  = "$desktop\Causality Model.lnk"
        if (Test-Path $lnkPath) {
            Write-Log "  Raccourci bureau deja present, skip." -Color Gray
        } else {
            $shortcut = $shell.CreateShortcut($lnkPath)
            $shortcut.TargetPath       = "cmd.exe"
            $shortcut.Arguments        = "/c `"$appInstallDir\launch.bat`""
            $shortcut.WorkingDirectory = $appInstallDir
            $shortcut.WindowStyle      = 1
            $shortcut.Description      = "Lancer Causality Model"
            $shortcut.Save()
            Write-Log "  Raccourci bureau cree -> $appInstallDir\launch.bat" -Color Green
        }
    } catch {
        Write-Log "  WARNING: impossible de creer le raccourci bureau: $_" -Color Yellow
    }
}

Write-Log ""
Flush-ToRelay "Step 3 done"


# =============================================================================
# Step 4 - Launch
# =============================================================================
Write-Log "[4/4] Launching application..." -Color Yellow
Write-Log "========================================" -Color Cyan
Write-Log ""
Flush-ToRelay "Step 4 - launching"

& $venvPython $APP_FILE

Write-Log ""
Write-Log "Application closed." -Color Cyan
Flush-ToRelay "Application closed"
Read-Host "Press Enter to exit"

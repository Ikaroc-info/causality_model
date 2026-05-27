<#
.SYNOPSIS
    Setup and run the Causality Model application.
.DESCRIPTION
    Installe Python 3.11 via le .exe officiel (chemin user par defaut, sans admin),
    poll jusqu'a completion reelle, puis cree un venv et lance app.py.
    Si RELAY_URL est defini, tous les logs sont aussi envoyes en POST.
#>

# --- Configuration ---
$PYTHON_VERSION    = "3.11.9"
$VENV_DIR          = ".venv"
$REQUIREMENTS_FILE = "requirements.txt"
$APP_FILE          = "app.py"
$INSTALLER_NAME    = "python-$PYTHON_VERSION-amd64.exe"
$INSTALLER_URL     = "https://www.python.org/ftp/python/$PYTHON_VERSION/$INSTALLER_NAME"

# URL du relay server (laisser vide pour desactiver)
# Exemple: $RELAY_URL = "http://192.168.1.42:8765/log"
$RELAY_URL = "http://192.168.1.45:8765/log"

# Python s'installe dans le chemin user par defaut (pas de TargetDir custom)
# Cela evite le bug ou Lib/ est absent apres install avec TargetDir personnalise
$pythonDir  = "$env:LOCALAPPDATA\Programs\Python\Python311"
$pythonExe  = "$pythonDir\python.exe"
$venvPython = "$PSScriptRoot\$VENV_DIR\Scripts\python.exe"
$venvPip    = "$PSScriptRoot\$VENV_DIR\Scripts\pip.exe"

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
Write-Log ""

# =============================================================================
# Step 0 - Clean
# =============================================================================
Write-Log "[0/4] Cleaning previous installation..." -Color Yellow

# Supprime le Python precedemment installe (chemin user)
if (Test-Path $pythonDir) {
    Write-Log "  Removing previous Python dir: $pythonDir" -Color Gray
    Remove-Item -Recurse -Force $pythonDir -ErrorAction SilentlyContinue
    if (Test-Path $pythonDir) {
        Write-Log "  WARNING: could not fully remove Python dir." -Color Yellow
    } else {
        Write-Log "  Removed." -Color Green
    }
}

# Supprime le venv
if (Test-Path $VENV_DIR) {
    Write-Log "  Removing previous .venv..." -Color Gray
    Remove-Item -Recurse -Force $VENV_DIR -ErrorAction SilentlyContinue
    if (-not (Test-Path $VENV_DIR)) { Write-Log "  Removed." -Color Green }
}

# Nettoie les cles de registre Python 3.11 pour eviter que l'installeur
# entre en mode Modifier/Reparer silencieux (bloquant sans afficher de fenetre).
Write-Log "  Cleaning Python 3.11 registry entries..." -Color Gray

$pythonCoreKey = "HKCU:\Software\Python\PythonCore"
if (Test-Path $pythonCoreKey) {
    Get-ChildItem $pythonCoreKey -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.PSChildName -like "3.11*") {
            Write-Log "    Removing: $($_.PSChildName)" -Color Gray
            Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$uninstallRoot = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
if (Test-Path $uninstallRoot) {
    Get-ChildItem $uninstallRoot -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($props.DisplayName -like "*Python 3.11*") {
            Write-Log "    Removing uninstall entry: $($props.DisplayName)" -Color Gray
            Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Log "  Registry cleaned." -Color Green
Write-Log ""
Flush-ToRelay "Step 0 done"

# =============================================================================
# Step 1 - Install Python 3.11 (chemin user par defaut, sans TargetDir custom)
# =============================================================================
Write-Log "[1/4] Installing Python $PYTHON_VERSION..." -Color Yellow

$instPath = "$env:TEMP\$INSTALLER_NAME"

try {
    Write-Log "  Downloading installer (~25 MB)..." -Color Gray
    Invoke-WebRequest -Uri $INSTALLER_URL -OutFile $instPath -UseBasicParsing
    $sizeMB = [math]::Round((Get-Item $instPath).Length / 1MB, 1)
    Write-Log "  Download complete ($sizeMB MB)." -Color Gray

    # Installer sans TargetDir custom = chemin par defaut qui fonctionne correctement.
    # Include_tcltk=1 garantit tkinter.
    # On NE PAS mettre de TargetDir ici — c'est ce qui causait l'absence de Lib/.
    $installArgs = @(
        "/quiet", "/norestart",
        "InstallAllUsers=0",
        "PrependPath=0",
        "Include_test=0",
        "Include_launcher=0",
        "Include_doc=0",
        "Include_tcltk=1"
    )

    Write-Log "  Starting installer (silent, user install)..." -Color Gray
    Write-Log "  Install dir: $pythonDir" -Color Gray
    # -Wait: attend que le bootstrapper ET ses enfants msiexec terminent
    $proc = Start-Process -FilePath $instPath -ArgumentList $installArgs -Wait -PassThru
    $exitCode = $proc.ExitCode
    Remove-Item $instPath -ErrorAction SilentlyContinue
    Write-Log "  Installer exit code: $exitCode" -Color Gray

    if ($exitCode -ne 0) {
        Exit-WithError "Installer failed (exit $exitCode). 1602=UAC annule, 1603=erreur fatale, 1618=install en cours."
    }

    # Poll jusqu'a ce que Lib\os.py apparaisse.
    # Le bootstrapper quitte immediatement apres avoir lance msiexec en fond.
    # -Wait attend le bootstrapper seulement, pas ses enfants. D'ou le poll long.
    Write-Log "  Waiting for Lib\os.py (up to 5 min)..." -Color Gray
    $timeoutSec = 300
    $elapsed    = 0
    $ready      = $false
    while ($elapsed -lt $timeoutSec) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        if (Test-Path "$pythonDir\Lib\os.py") {
            $ready = $true
            Write-Log "  Lib\os.py found! ($elapsed s)" -Color Green
            break
        }
        if ($elapsed % 15 -eq 0) {
            Write-Log "  Still waiting... ($elapsed / $timeoutSec s)" -Color Gray
            Flush-ToRelay "Step 1 - waiting"
        }
    }

    # Si introuvable au chemin attendu, chercher python.exe ailleurs dans LocalAppData
    if (-not $ready) {
        Write-Log "  Lib\os.py not found at expected path. Searching LocalAppData..." -Color Yellow
        Write-Log "  Contents of $env:LOCALAPPDATA\Programs:" -Color Gray
        if (Test-Path "$env:LOCALAPPDATA\Programs") {
            Get-ChildItem "$env:LOCALAPPDATA\Programs" -ErrorAction SilentlyContinue |
                ForEach-Object { Write-Log "    $($_.Name)" -Color Gray }
        }
        $foundExe = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs" -Filter "python.exe" `
                        -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -notlike "*WindowsApps*" -and $_.FullName -notlike "*Scripts*" } |
                    Select-Object -First 1
        if ($foundExe) {
            Write-Log "  Found python.exe at: $($foundExe.FullName)" -Color Yellow
            $script:pythonDir = $foundExe.DirectoryName
            $script:pythonExe = $foundExe.FullName
            if (Test-Path "$($foundExe.DirectoryName)\Lib\os.py") {
                Write-Log "  Lib\os.py confirmed at alternate path!" -Color Green
                $ready = $true
            } else {
                Write-Log "  WARNING: python.exe found but Lib\os.py still missing at $($foundExe.DirectoryName)" -Color Yellow
            }
        } else {
            Write-Log "  No python.exe found anywhere in LocalAppData\Programs." -Color Red
        }
    }

    if (-not $ready) {
        Exit-WithError "Python install completed but Lib\os.py not found. Check above for alternate paths."
    }

    # Contenu du dossier pour debug
    Write-Log "  Contents of $pythonDir :" -Color Gray
    if (Test-Path $pythonDir) {
        Get-ChildItem $pythonDir | ForEach-Object { Write-Log "    $($_.Name)" -Color Gray }
    }

} catch {
    Remove-Item $instPath -ErrorAction SilentlyContinue
    Exit-WithError "Installer download or launch failed: $_"
}


# Set PYTHONHOME so Python always finds its stdlib
$env:PYTHONHOME       = $pythonDir
$env:PYTHONUTF8       = "1"
$env:PYTHONIOENCODING = "utf-8"

# Verify python + tkinter
if (Test-PythonOk $pythonExe) {
    $ver = & $pythonExe --version 2>&1
    Write-Log "  Python: $ver" -Color Green
    Write-Log "  tkinter: OK" -Color Green
} else {
    $ver  = & $pythonExe --version 2>&1
    $tkOk = & $pythonExe -c "import tkinter; print('ok')" 2>&1
    Write-Log "  [DEBUG] ver : $ver"  -Color Gray
    Write-Log "  [DEBUG] tk  : $tkOk" -Color Gray
    Exit-WithError "Python or tkinter check failed after install."
}

Write-Log ""
Flush-ToRelay "Step 1 done"

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
Flush-ToRelay "Step 2 done"

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
Flush-ToRelay "Step 3 done"

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

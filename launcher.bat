@echo off
setlocal enabledelayedexpansion

:: =============================================================================
:: Antigravity Causal — Windows Launcher
:: =============================================================================

title Antigravity Causal - Launching...

echo ------------------------------------------------------------------
echo   Antigravity Causal - Windows Launcher
echo ------------------------------------------------------------------
echo.

:: 1. Check for Python
echo [1/4] Checking for Python...
where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python not found! Please install Python from python.org
    pause
    exit /b 1
)
for /f "tokens=*" %%i in ('python --version') do set pyver=%%i
echo Found: !pyver!

:: 2. Setup Virtual Environment
echo [2/4] Setting up environment...
if not exist venv (
    echo Creating virtual environment (first time only)...
    python -m venv venv
)

:: 3. Install Dependencies
echo [3/4] Installing/Updating dependencies...
call venv\Scripts\activate.bat
python -m pip install --upgrade pip --quiet
python -m pip install -r requirements.txt --quiet

:: 4. Launch Application
echo [4/4] Launching server...
echo.
echo ------------------------------------------------------------------
echo   SERVER IS STARTING!
echo   Your browser will open automatically in a few seconds.
echo   Keep this window open while using the app.
echo ------------------------------------------------------------------
echo.

python server.py

:: If the server stops, keep the window open so they can see why
echo.
echo Server has stopped.
pause

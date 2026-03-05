@echo off
setlocal

title Antigravity Causal - Launching...

echo ------------------------------------------------------------------
echo   Antigravity Causal - Launcher
echo ------------------------------------------------------------------
echo.

where python >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Python not found! Please install Python from python.org
    pause
    exit /b 1
)

python "%~dp0launcher.py"

if %ERRORLEVEL% neq 0 (
    echo.
    echo Launcher exited with an error.
    pause
)

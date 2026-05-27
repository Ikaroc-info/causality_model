@echo off
:: Causality Model - Launcher
:: Usage:
::   launch.bat          -> reutilise l'installation existante (plus rapide)
::   launch.bat -Clean   -> supprime et reinstalle Python + venv depuis zero

:: Se placer dans le repertoire du .bat avant de lancer PowerShell
:: pour que $PSScriptRoot soit correct dans le script.
cd /d "%~dp0"
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_and_run.ps1" %*

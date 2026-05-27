@echo off
:: Causality Model - Launcher
:: Double-cliquez sur ce fichier pour lancer l'application.

:: Se placer dans le repertoire du .bat avant de lancer PowerShell
:: pour que $PSScriptRoot soit correct dans le script.
cd /d "%~dp0"
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_and_run.ps1"

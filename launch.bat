@echo off
:: Causality Model - Launcher
:: Double-cliquez sur ce fichier pour lancer l'application.
:: Il appelle setup_and_run.ps1 en contournant la politique d'execution PowerShell.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_and_run.ps1"

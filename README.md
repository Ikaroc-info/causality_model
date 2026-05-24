# Causal Experience Manager

A pure Python desktop application for calculating Causal effects using Microsoft DoWhy, pandas, and customtkinter.

## 🚀 Getting Started (Windows)

> **No installation required.** Everything is handled automatically.

**Double-cliquez sur `launch.bat`** — c'est tout.

Le script s'occupe automatiquement de :
1. Télécharger et installer Python 3.11 localement (sans droits admin, sans modifier le système)
2. Créer un environnement virtuel `.venv`
3. Installer toutes les dépendances depuis `requirements.txt`
4. Lancer l'application

> ℹ️ La première exécution peut prendre quelques minutes (téléchargement de Python et des dépendances).
> Les lancements suivants sont quasi-instantanés.

## Features
- **CSV Data Loading**: Choose your datasets via standard file dialog.
- **Variable Selection**: Pick your Treatments (causes), Outcomes (effects), and Confounders (controls).
- **Backend Model**:
  - `dowhy` for Causal Inference.
  - Linear Regression, Propensity Score methods.
  - Robustness checks via Refuters (Placebo, Random Common Cause).
- **Diagnostics**:
  - Standardized Mean Difference (SMD) rendered directly using Matplotlib.
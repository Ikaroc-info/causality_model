# Causal Experience Manager

A pure Python desktop application for calculating Causal effects using Microsoft DoWhy, pandas, and customtkinter.

## Prerequisites

Make sure you have Python 3.8+ installed.

## Installation

Install the required dependencies via pip:

```bash
pip install -r requirements.txt
```

*(Optional but recommended: use a virtual environment `python -m venv venv` before installing requirements)*

## Running the Application

Launch the desktop application with:

```bash
python app.py
```

## Features
- **CSV Data Loading**: Choose your datasets via standard file dialog.
- **Variable Selection**: Pick your Treatments (causes), Outcomes (effects), and Confounders (controls).
- **Backend Model**:
  - `dowhy` for Causal Inference.
  - Linear Regression, Propensity Score methods.
  - Robustness checks via Refuters (Placebo, Random Common Cause).
- **Diagnostics**:
  - Standardized Mean Difference (SMD) rendered directly using Matplotlib.
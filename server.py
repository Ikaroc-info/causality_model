from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import pandas as pd
import numpy as np
import dowhy
from dowhy import CausalModel
import networkx as nx
from networkx.drawing.nx_pydot import to_pydot
import io
import base64
import os
import sys
import threading
import webbrowser
from fastapi.middleware.cors import CORSMiddleware

# ── Locate frontend dist/ (works both in dev and when frozen by PyInstaller) ──
if getattr(sys, 'frozen', False):
    # Running as a PyInstaller one-file binary; assets are in a temp folder
    _BASE_DIR = sys._MEIPASS  # type: ignore[attr-defined]
else:
    _BASE_DIR = os.path.dirname(os.path.abspath(__file__))

_DIST_DIR = os.path.join(_BASE_DIR, 'dist')

app = FastAPI()

# ── Auto-open browser once the server is ready ────────────────────────────────
HOST = '127.0.0.1'
PORT = 8000

@app.on_event('startup')
async def open_browser():
    url = f'http://{HOST}:{PORT}'
    def _open():
        import time
        time.sleep(0.8)  # tiny delay so uvicorn is fully listening
        webbrowser.open(url)
    threading.Thread(target=_open, daemon=True).start()

# NOTE: Static file mounts are registered at the BOTTOM of this file,
# after all API routes, so that POST /analyze is not shadowed by the
# catch-all '/' mount (FastAPI matches routes in registration order).

# Enable CORS for frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Sanitize helper for JSON compliance
def sanitize_float(val):
    if val is None:
        return 0.0
    if isinstance(val, (float, np.floating)):
        if np.isnan(val) or np.isinf(val):
            return 0.0
    return float(val)

def calculate_smd(df, treatment_col, confounders):
    smd_data = []
    if not confounders:
        return smd_data
        
    treated = df[df[treatment_col] == 1]
    control = df[df[treatment_col] == 0]
    
    for col in confounders:
        try:
            mean_t = treated[col].mean()
            mean_c = control[col].mean()
            var_t = treated[col].var()
            var_c = control[col].var()
            
            pooled_std = np.sqrt((var_t + var_c) / 2)
            if pooled_std == 0 or np.isnan(pooled_std):
                smd = 0
            else:
                smd = (mean_t - mean_c) / pooled_std
            
            smd_data.append({"variable": col, "smd": sanitize_float(smd)})
        except Exception:
            smd_data.append({"variable": col, "smd": 0.0})
            
    return smd_data

class CausalRequest(BaseModel):
    data: List[dict]
    treatment: List[str]
    outcome: str
    common_causes: List[str] = []
    estimator_method: str = "backdoor.linear_regression"
    refuter_method: str = "random_common_cause" # Default to Random Common Cause

@app.post("/analyze")
async def analyze_causal_effect(request: CausalRequest):
    try:
        df = pd.DataFrame(request.data)
        df.dropna(inplace=True) # Handle missing values

        if df.empty:
            raise HTTPException(status_code=400, detail="Dataset is empty after removing missing values.")
        
        # Validate columns
        if not all(col in df.columns for col in request.treatment):
            raise HTTPException(status_code=400, detail=f"Treatment columns {request.treatment} not found in data")
        if request.outcome not in df.columns:
            raise HTTPException(status_code=400, detail=f"Outcome column {request.outcome} not found in data")
            
        # Validate Propensity Score requirements
        if "propensity" in request.estimator_method:
            if not request.common_causes:
                raise HTTPException(
                    status_code=400, 
                    detail="Propensity score methods require at least one Control variable (confounder). Please select variables in 'Adjust for Confounders'."
                )
            # Check if treatment is binary
            for treatment_var in request.treatment:
                unique_vals = df[treatment_var].unique()
                if len(unique_vals) > 2:
                     raise HTTPException(
                        status_code=400, 
                        detail=f"Propensity score methods require a binary treatment (0 or 1). Variable '{treatment_var}' has {len(unique_vals)} unique values."
                    )
            
        results = {}
        
        # Iterate over each treatment variable if multiple are selected
        for treatment_var in request.treatment:
            model = CausalModel(
                data=df,
                treatment=treatment_var,
                outcome=request.outcome,
                common_causes=request.common_causes
            )
            
            # Identify causal effect
            identified_estimand = model.identify_effect(proceed_when_unidentifiable=True)
            
            # Estimate causal effect using the selected method
            estimate = model.estimate_effect(
                identified_estimand,
                method_name=request.estimator_method
            )
            
            # Refute the estimate using selected method
            refute = model.refute_estimate(
                identified_estimand, 
                estimate,
                method_name=request.refuter_method
            )
            
            # Advanced Reporting logic
            # 1. DOT Graph
            try:
                dot_graph = to_pydot(model._graph._graph).to_string()
            except Exception as e:
                print(f"Error generating DOT graph: {e}")
                dot_graph = None
            
            # 2. Backdoor Paths
            try:
                backdoor_paths = model._graph.get_backdoor_paths([treatment_var], [request.outcome])
            except Exception as e:
                print(f"Error getting backdoor paths: {e}")
                backdoor_paths = []
                
            # 3. Covariate Balance (SMD) - only for propensity methods or if confounders exist
            smd_data = []
            try:
                if request.common_causes:
                     smd_data = calculate_smd(df, treatment_var, request.common_causes)
            except Exception as e:
                print(f"Error calculating SMD: {e}")

            results[treatment_var] = {
                "ate": sanitize_float(estimate.value),
                "identified_estimand": str(identified_estimand),
                "refutation_result": sanitize_float(refute.new_effect),
                "dot_graph": dot_graph,
                "backdoor_paths": backdoor_paths,
                "smd": smd_data,
                "graph": {
                    "nodes": list(model._graph._graph.nodes()),
                    "edges": list(model._graph._graph.edges())
                }
            }

        return {
            "status": "success",
            "results": results,
            "sample_size": len(df)
        }

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

# ── Serve the React frontend (registered LAST so API routes take priority) ───
# StaticFiles at '/' is a catch-all: anything not matched by an API route
# above will be served as a static file (or index.html for SPA routing).
@app.get('/', include_in_schema=False)
async def root():
    return RedirectResponse(url='/index.html')

if os.path.isdir(_DIST_DIR):
    if os.path.isdir(os.path.join(_DIST_DIR, 'assets')):
        app.mount('/assets', StaticFiles(directory=os.path.join(_DIST_DIR, 'assets')), name='assets')
    app.mount('/', StaticFiles(directory=_DIST_DIR, html=True), name='frontend')

if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host=HOST, port=PORT)

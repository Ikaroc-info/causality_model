import pandas as pd
import numpy as np
from dowhy import CausalModel
import networkx as nx

# Create dummy data with some confounding
np.random.seed(42)
n_samples = 1000
confounder = np.random.normal(0, 1, n_samples)
# Treatment depends on confounder
treatment_prob = 1 / (1 + np.exp(-confounder))
treatment = np.random.binomial(1, treatment_prob, n_samples)
# Outcome depends on treatment and confounder
outcome = 2 * treatment + 3 * confounder + np.random.normal(0, 1, n_samples)

df = pd.DataFrame({
    'treatment': treatment,
    'outcome': outcome,
    'confounder': confounder
})

# Create CausalModel
model = CausalModel(
    data=df,
    treatment='treatment',
    outcome='outcome',
    common_causes=['confounder']
)

# 1. DOT Graph
print("\n--- DOT Graph ---")
try:
    # Try different ways to get DOT
    import networkx as nx
    from networkx.drawing.nx_pydot import to_pydot
    dot_string = to_pydot(model._graph._graph).to_string()
    print(dot_string[:100], "...")
except Exception as e:
    print("Error extracting DOT:", e)

# 2. Backdoor Paths
print("\n--- Backdoor Paths ---")
try:
    identified_estimand = model.identify_effect()
    print("Identified Estimand:", identified_estimand)
    # Check if we can get paths directly from graph
    # DoWhy's internal graph might have this
    paths = model._graph.get_backdoor_paths(['treatment'], ['outcome'])
    print("Backdoor Paths:", paths)
except Exception as e:
    print("Error extracting paths:", e)


# 3. Propensity Scores & Balance
print("\n--- Propensity & Balance ---")
try:
    estimate = model.estimate_effect(
        identified_estimand,
        method_name="backdoor.propensity_score_weighting"
    )
    
    # Check for propensity scores
    if hasattr(estimate, 'control_propensity_scores'):
        print("Control PS available")
        
    # Check for SMD/Balance
    # DoWhy doesn't automatically calculate SMD in estimate object usually?
    # We might need to manualy calc SMD
    
    def calculate_smd(df, treatment_col, confounders):
        smd_data = {}
        treated = df[df[treatment_col] == 1]
        control = df[df[treatment_col] == 0]
        
        for col in confounders:
            mean_t = treated[col].mean()
            mean_c = control[col].mean()
            var_t = treated[col].var()
            var_c = control[col].var()
            
            pooled_std = np.sqrt((var_t + var_c) / 2)
            smd = (mean_t - mean_c) / pooled_std
            smd_data[col] = smd
        return smd_data

    smd_pre = calculate_smd(df, 'treatment', ['confounder'])
    print("SMD Pre-adjustment:", smd_pre)
    
except Exception as e:
    print("Error in PS/Balance:", e)

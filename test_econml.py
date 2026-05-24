import pandas as pd
import numpy as np
from dowhy import CausalModel
from sklearn.ensemble import RandomForestRegressor, RandomForestClassifier

test_data = []
for _ in range(300):
    age = np.random.randint(20, 60)
    education = np.random.randint(12, 20)
    is_treated = 1 if np.random.rand() < (0.3 + (age / 100)) else 0
    base_income = 1500 + age * 25 + education * 80
    income = base_income + (is_treated * 450) + (np.random.rand() * 300 - 150)
    test_data.append([age, education, is_treated, int(income)])
    
df = pd.DataFrame(test_data, columns=["age", "education", "treatment", "income"])

model = CausalModel(
    data=df,
    treatment="treatment",
    outcome="income",
    common_causes=["age", "education"],
    effect_modifiers=["age", "education"]
)
identified_estimand = model.identify_effect(proceed_when_unidentifiable=True)
estimate = model.estimate_effect(
    identified_estimand,
    method_name="backdoor.econml.dml.LinearDML",
    method_params={
        "init_params": {
            'model_y': RandomForestRegressor(n_estimators=50),
            'model_t': RandomForestClassifier(n_estimators=50),
            'discrete_treatment': True
        },
        "fit_params": {}
    }
)
print("Estimate DML:", estimate.value)

estimate_x = model.estimate_effect(
    identified_estimand,
    method_name="backdoor.econml.metalearners.XLearner",
    method_params={
        "init_params": {
            'models': RandomForestRegressor(n_estimators=50)
        },
        "fit_params": {}
    }
)
print("Estimate XLearner:", estimate_x.value)

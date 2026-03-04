import json
import numpy as np

def calculate_smd_bad(df):
    # Simulate a case where we get NaN or Inf
    return [
        {"variable": "v1", "smd": float('nan')},
        {"variable": "v2", "smd": float('inf')},
        {"variable": "v3", "smd": -float('inf')}
    ]

data = {
    "ate": 0.5,
    "smd": calculate_smd_bad(None)
}

print("Attempting to dump JSON...")
try:
    json.dumps(data)
except ValueError as e:
    print(f"Caught expected error: {e}")
except Exception as e:
    print(f"Caught unexpected error: {e}")

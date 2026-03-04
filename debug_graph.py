import pandas as pd
from dowhy import CausalModel
import networkx as nx

# Create dummy data
df = pd.DataFrame({
    'treatment': [0, 1, 0, 1],
    'outcome': [1, 2, 1, 2],
    'confounder': [0.5, 0.6, 0.5, 0.6]
})

# Create CausalModel
model = CausalModel(
    data=df,
    treatment='treatment',
    outcome='outcome',
    common_causes=['confounder']
)

print("Type of model._graph:", type(model._graph))
print("Dir of model._graph:", dir(model._graph))

try:
    print("Nodes:", model._graph.nodes())
except Exception as e:
    print("Error accessing nodes:", e)

# Check if it has a graph attribute
if hasattr(model._graph, '_graph'):
    print("Type of model._graph._graph:", type(model._graph._graph))
    print("Nodes from internal graph:", model._graph._graph.nodes())

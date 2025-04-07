import numpy as np
from stable_baselines3 import PPO
import pandas as pd

# Charger le modèle PPO que tu as entraîné
model = PPO.load("aqua_ppo_hybrid_model")

# Lire l’état depuis le fichier CSV généré par NetLogo
state_df = pd.read_csv("env_state.csv", header=None)
state = state_df.values.flatten().astype(np.float32)  # [turbidity, temp, oxygen, alk, ph, ammonia, phos, plankton, nitrite, co2]

# Ajouter une valeur de qualité fictive (0) pour correspondre à l’espace d’observation du PPO (11 dimensions)
full_state = np.append(state, 0).astype(np.float32)

# Prédire l’action avec le modèle PPO
action, _ = model.predict(full_state, deterministic=True)

# Écrire l’action dans un fichier CSV
pd.DataFrame([action]).to_csv("ppo_action.csv", index=False, header=False)

print(f"Action prédite : {action}")
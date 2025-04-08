import numpy as np
import pandas as pd
from stable_baselines3 import PPO
import time

# Load the PPO model
model = PPO.load("aqua_ppo_hybrid_model")

# Read the environment state from CSV, using the first row as header
state_df = pd.read_csv("C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv")

# Extract the data row (skip the header)
state = state_df.iloc[0].values.astype(np.float32)  # 11 values

# Labels for display (10 environmental variables, excluding current_line)
labels = ["Turbidité", "Température", "Oxygène", "Alcalinité", "pH", "Ammoniaque", "Phosphates", "Plancton", "Nitrites", "CO₂"]
print("\n--- État actuel de l'eau ---")
for label, value in zip(labels, state[:-1]):  # Exclude current_line
    print(f"{label} : {value}")

# Use state directly (no extra 0 appended)
full_state = state.astype(np.float32)  # Shape: (11,)

# Predict the action
action, _ = model.predict(full_state, deterministic=True)
print("\nAction prédite :", action)

# Save the action to ppo_action.csv
pd.DataFrame([action]).to_csv("ppo_action.csv", index=False, header=False)
print("Action sauvegardée dans 'ppo_action.csv'")

# Optional delay (reduced for testing)
time.sleep(1)
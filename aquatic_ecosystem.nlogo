extensions [csv]

globals [
  temperature
  turbidity
  oxygen
  co2
  ph
  ammonia
  alkalinity
  nitrite
  phosphorus
  plankton
  pollution
  bod
  h2s
  dead-fish
  fish-before
  data-lines
  current-line
  plant-count
  hardness
  calcium
  water-quality
  action-count ;; Nouvelle variable pour suivre le nombre d'actions
   living-fish
]

breed [fishes fish]
breed [plants plant]

fishes-own [health]

to setup
  clear-all
  clear-output
  set-default-shape fishes "fish"
  setup-lake

  ;; Lire les données CSV
file-open "C:/Users/Hp/Desktop/AquaSim-Innovators/donnees_final_data.csv"

  set data-lines []
  let line-count 0
  while [not file-at-end?] [
    let line file-read-line
    if line-count > 0 [  ;; Ignore la première ligne (en-tête)
      set data-lines lput (parse-csv-line line) data-lines
    ]
    set line-count line-count + 1
  ]
  file-close

  set current-line 0
  set dead-fish 0
  set action-count 0 ;; Initialisation du compteur d'actions
  set living-fish 0 ;; Initialisation du compteur de poissons vivants

  ;; Créer les poissons
  create-fishes 100 [
    setxy random-xcor random-ycor
    set color blue
    set size 1.5
    set health 100
    set living-fish living-fish + 1 ;; Incrémenter le nombre de poissons vivants

  ]

  ;; Créer les plantes
  set plant-count 100
  create-plants plant-count

  reset-ticks
end

to-report parse-csv-line [line]
  report csv:from-row line
end

to go
  if current-line >= length data-lines [
    show "Simulation terminée"
    stop
  ]

  set fish-before count fishes
  update-environment  ;; Exporte l’état dans env_state.csv

  ;; Pause manuelle : affiche un message et attends que tu exécutes Python
  show "Exécute 'python run_ppo.py' dans un terminal, puis clique sur Continuer."
  user-message "Exécute 'python run_ppo.py' dans un terminal, puis clique OK pour continuer."
  
  wait-for-action "ppo_action.csv"  ;; Attend que ppo_action.csv soit créé
  apply-ppo-action  ;; Applique l’action PPO

  ask fishes [
    move
    evaluate-environment
    search-for-plants
  ]

  set dead-fish dead-fish + (fish-before - count fishes)
  grow-plants
  set current-line current-line + 1
  tick
end

to wait-for-action [filename]
  let max-wait 30  ;; Temps maximum d’attente en secondes (ajuste si nécessaire)
  let waited 0
  while [not file-exists? filename and waited < max-wait] [
    wait 0.1  ;; Vérifie toutes les 0.1 secondes
    set waited waited + 0.1
  ]
  if not file-exists? filename [
    show "Erreur : ppo_action.csv n’a pas été créé dans le temps imparti."
    stop
  ]
end

to update-environment
  let row item current-line data-lines
  show (word "Processing Row " current-line ": " row)

  let temp-csv read-number item 0 row
  let turb-csv read-number item 1 row
  let oxy-csv read-number item 2 row
  let co2-csv read-number item 3 row
  let ph-csv read-number item 5 row
  let alk-csv read-number item 4 row
  let amm-csv read-number item 6 row
  let nit-csv read-number item 7 row
  let phos-csv read-number item 8 row
  let plank-csv read-number item 9 row
  set water-quality item 10 row

  set temperature temp-csv + (Temperature - temp-csv) * 0.1
  set turbidity turb-csv
  set oxygen oxy-csv + (Oxygen - oxy-csv) * 0.1
  set co2 co2-csv + (CO2 - co2-csv) * 0.1
  set ph ph-csv + (pH - ph-csv) * 0.1
  set alkalinity alk-csv
  set ammonia amm-csv + (Ammonia - amm-csv) * 0.1
  set nitrite nit-csv + (Nitrite - nit-csv) * 0.1
  set phosphorus phos-csv + (Phosphorus - phos-csv) * 0.1
  set plankton plank-csv
  set pollution Pollution

  set bod 6
  set hardness 0
  set calcium 0
  set h2s 0

  ;; Export the environment state to CSV
  let state-list (list turbidity temperature oxygen alkalinity ph ammonia phosphorus plankton nitrite co2)
  csv:to-file "C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv" (list state-list)

  ;; Pollution check and handling
  if pollution > 50 [
    show "Pollution trop haute! Traitement de l'eau déclenché."
    user-message "Alerte: Pollution trop haute! Traitement de l'eau déclenché."
    set oxygen oxygen + 2
  ]
  if oxygen < 3 [
    show "Alerte: Manque d’oxygène! Les poissons sont en danger."
    user-message "Alerte: Manque d’oxygène!"
    ask fishes [
      set health health - 10
      if health <= 0 [
        die
      ]
      ;; Change color based on health status
      if health < 20 [
        set color red  ;; Fish turns red when health is low
      ]
      if health >= 20 and health < 50 [
        set color orange  ;; Fish turns orange for moderate health
      ]
      if health >= 50 [
        set color green  ;; Fish turns green when health is good
      ]
    ]
  ]
  if pollution > 80 [
    show "Alerte: Pollution extrême! Les poissons meurent."
    user-message "Alerte: Pollution extrême!"
    ask fishes [
      set health health - 20
      if health <= 0 [
        die
      ]
      ;; Color change when the fish is highly affected
      if health < 20 [
        set color red
      ]
    ]
  ]
  if temperature > 30 [
    show "Température trop élevée! Risque de stress pour les poissons."
    user-message "Alerte: Température trop élevée!"
    set oxygen oxygen - 1
    ask fishes [
      set health health - 5  ;; Reduce fish health due to high temperature
      if health < 20 [
        set color orange  ;; Stress affects health, fish turns orange
      ]
    ]
  ]
end


to-report read-number [x]
  if is-number? x [ report x ]

  if is-string? x [
    if (x = "" or x = "NA") [ report 0 ]
    let cleaned replace-comma-with-dot x
    let number read-from-string cleaned
    ifelse is-number? number [
      report number
    ] [
      report 0
    ]
  ]

  report 0
end

to-report replace [old-char new-char str]
  let result ""
  let i 0
  while [i < length str] [
    ifelse (substring str i (i + 1)) = old-char [
      set result (word result new-char)
    ] [
      set result (word result (substring str i (i + 1)))
    ]
    set i i + 1
  ]
  report result
end

to-report replace-comma-with-dot [s]
  if not is-string? s [ report "0" ]
  report replace "," "." s
end

to move
  rt random-float 30 - random-float 30
  fd 1
end
to setup-lake
  ;; Initialisation des paramètres de l'environnement aquatique
  set temperature 25
  set turbidity 0
  set oxygen 8
  set co2 5
  set ph 7
  set ammonia 0.5
  set nitrite 0.1
  set phosphorus 0.3
  set plankton 10
  set pollution 56
  set bod 5
  set hardness 20
  set calcium 15
  set h2s 0
end
to evaluate-environment
  let stress 0
  if temperature > 25 [ set stress stress + (temperature - 25) * 0.5 ]
  if oxygen < 6.5 [ set stress stress + (6.5 - oxygen) * 2 ]
  if bod > 6 [ set stress stress + (bod - 6) ]
  if ammonia > 1 [ set stress stress + (ammonia - 1) * 3 ]
  if co2 > 10 [ set stress stress + (co2 - 10) * 0.5 ]
  if turbidity > 50 [ set stress stress + (turbidity - 50) * 0.1 ]
  if (ph < 6.5 or ph > 8.5) [ set stress stress + 5 ]
  if h2s > 0.5 [ set stress stress + (h2s - 0.5) * 4 ]
  if nitrite > 1 [ set stress stress + (nitrite - 1) * 2 ]
  if phosphorus > 0.5 [ set stress stress + (phosphorus - 0.5) * 1.5 ]

  set health health - stress
  if health > 75 [ set color blue ]
  if health <= 75 and health > 40 [ set color orange ]
  if health <= 40 [ set color red ]
  if health <= 0 [ die ]
end
to apply-ppo-action
  let action-file "ppo_action.csv"
  if file-exists? action-file [
    let action-data csv:from-file action-file
    let action read-number (item 0 (item 0 action-data))
    show (word "Action PPO prédite : " action)

    if action = 1 [
      set turbidity (turbidity - 5.0) if turbidity > 5.0 [set turbidity 0]
      set ammonia (ammonia - 0.2) if ammonia > 0.2 [set ammonia 0]
      set nitrite (nitrite - 0.3) if nitrite > 0.3 [set nitrite 0]
      set co2 (co2 - 0.2) if co2 > 0.2 [set co2 0]
      set oxygen (oxygen + 2)
    ]
    if action = 2 [
      set alkalinity (alkalinity + 10.0) if alkalinity < 500 [set alkalinity 500]
      set turbidity (turbidity + 2.0) if turbidity < 100 [set turbidity 100]
      set ammonia (ammonia - 0.1) if ammonia > 0.1 [set ammonia 0]
      set phosphorus (phosphorus - 0.05) if phosphorus > 0.05 [set phosphorus 0]
      set nitrite (nitrite - 0.15) if nitrite > 0.15 [set nitrite 0]
      set co2 (co2 + 0.8) if co2 < 15 [set co2 15]
      set oxygen (oxygen + 0.8) if oxygen < 15 [set oxygen 15]
    ]
    if action = 3 [  ;; Action 3 : Introduction de nouveaux poissons
      create-fishes 10 [
        setxy random-xcor random-ycor
        set color blue
        set size 1.5
        set health 100
      ]
      show "Nouvelle génération de poissons ajoutée!"
    ]
    if action = 4 [  ;; Action 4 : Ajustement de la température
      set temperature (temperature + 2)  ;; Augmenter la température
      show "Température augmentée!"
    ]
    if action = 5 [  ;; Action 5 : Ajustement du pH
      if ph < 8.5 [   ;; Vérifie si le pH est inférieur à 8.5
        set ph (ph + 0.5)  ;; Augmenter légèrement le pH
        show "pH ajusté!"
      ]
    ]
    if action = 6 [  ;; Action 6 : Ajustement de la dureté de l'eau
      set hardness (hardness + 5)
      show "Dureté de l'eau augmentée!"
    ]
    
    file-delete action-file  ;; Supprime le fichier pour éviter les conflits au prochain tick
  ]
end

to search-for-plants
  let nearest-plant one-of plants
  if nearest-plant != nobody [
    face nearest-plant
    fd 0.5
    if distance nearest-plant < 1 [
      ask nearest-plant [
        die  ;; Supprime la plante de l'environnement lorsque le poisson la mange
      ]
    ]
  ]
end






to grow-plants
  if random 100 < 5 [
    create-plants 1 [
      setxy random-xcor random-ycor
      set color green
    ]
  ]
end

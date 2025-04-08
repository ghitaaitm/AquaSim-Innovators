extensions [csv]

globals [
  temperature turbidity oxygen co2 ph ammonia alkalinity nitrite phosphorus plankton
  pollution bod h2s dead-fish fish-before data-lines current-line plant-count
  hardness calcium water-quality action-count living-fish seuil_de_pollution
]

breed [fishes fish]
breed [plants plant]
plants-own [health]
fishes-own [health]

to setup
  clear-all
  clear-output
  output-print "===== INITIALISATION DE LA SIMULATION ====="

  reset-ticks  ;; Move this up to initialize ticks before any checks

  ; Safety check - prevent multiple setups (now safe after reset-ticks)
  if ticks > 0 [
    clear-output
    output-print "ATTENTION: La simulation a déjà été configurée."
    output-print "Pour recommencer, utilisez 'reset-ticks' dans la barre de commande puis cliquez à nouveau sur 'Setup'."
    stop
  ]

  set-default-shape fishes "fish"
  setup-lake
  set seuil_de_pollution 50

  ; Load CSV data
  output-print "Chargement des données CSV..."
  file-open "C:/Users/Hp/Desktop/AquaSim-Innovators/donnees_final_data.csv"

  ; Explicitly skip the header row
  let header file-read-line
  output-print (word "En-tête ignoré: " header)  ;; Debug

  set data-lines []
  while [not file-at-end?] [
    let line file-read-line
    if line != "" [  ; Skip empty lines
      set data-lines lput (parse-csv-line line) data-lines
    ]
  ]
  file-close
  output-print (word "Données chargées: " length data-lines " lignes")

  set current-line 0
  set dead-fish 0
  set action-count 0
  set living-fish 0

  ; Create fish and plants
  create-fishes 100 [
    setxy random-xcor random-ycor
    set color blue
    set size 1.5
    set health 100
    set living-fish living-fish + 1
  ]

  ask patches [ set pcolor blue ]

  set plant-count 100
  create-plants plant-count [
    setxy random-xcor random-ycor
    set color green
    set size 1
    set health 100
  ]

  output-print "===== CONFIGURATION TERMINÉE ====="
  output-print "Cliquez sur 'Go' pour démarrer la simulation."
end

to setup-lake
  ask patches [ set pcolor blue ]
end

to-report parse-csv-line [line]
  report csv:from-row line
end

to go
  ; Clean up any stray files from previous runs
  if ticks = 0 [
    if file-exists? "ppo_action.csv" [
      file-delete "ppo_action.csv"
    ]
    if file-exists? "C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv" [
      file-delete "C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv"
    ]
  ]

  ; Check if we've reached the end of the data
  if current-line >= length data-lines [
    output-print "===== SIMULATION TERMINÉE ====="
    output-print (word "Poissons morts: " dead-fish)
    output-print (word "Poissons vivants: " living-fish)
    stop
  ]

  ; Get and process the current row
  let row item current-line data-lines
  output-print (word "Ligne actuelle: " (current-line + 1) " / " length data-lines)
  output-print (word "Processing Row: " row)

  ; Process environmental conditions
  set fish-before count fishes
  update-environment

  ; Update display based on conditions
  update-display

  ; Move and evaluate fish
  ask fishes [
    move
    evaluate-environment
    search-for-plants
  ]

  ; Get user input for PPO action
  handle-ppo-action

  ; Delete files after use
  if file-exists? "ppo_action.csv" [
    file-delete "ppo_action.csv"
    output-print "Fichier ppo_action.csv supprimé."
  ]

  if file-exists? "C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv" [
    file-delete "C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv"
    output-print "Fichier env_state.csv supprimé."
  ]

  ; Display summary for this tick
  output-print (word "Action count: " action-count)
  output-print (word "Nombre de poissons vivants: " count fishes)
  output-print (word "Niveau de pollution: " pollution)
  output-print (word "Niveau d'oxygène: " oxygen)
  output-print (word "Température: " temperature)
  output-print "---------------------------------------------"

  ; Increment line counter and tick
  set current-line current-line + 1
  tick
end

to handle-ppo-action
  ; Inform user to run the Python script
  output-print "Exécute 'python run_ppo.py' dans un terminal, puis clique sur Continuer."
  user-message "Exécute 'python run_ppo.py' dans un terminal, puis clique OK."

  ; Wait for the action file to be created
  output-print "Attente du fichier ppo_action.csv..."
  wait-for-action "ppo_action.csv"

  ; Check if file exists and apply action
  if file-exists? "ppo_action.csv" [
    output-print "Fichier ppo_action.csv trouvé, application de l'action PPO."
    apply-ppo-action
  ]
  if not file-exists? "ppo_action.csv" [
    output-print "Erreur : ppo_action.csv non trouvé."
  ]
end

to update-display
  ; Update water color based on pollution levels
  if pollution > seuil_de_pollution [
    ask patches [ set pcolor scale-color brown pollution seuil_de_pollution 100 ]
  ]
  if pollution <= seuil_de_pollution [
    ask patches [ set pcolor scale-color blue pollution 0 seuil_de_pollution ]
  ]

  ; Update fish colors based on environmental conditions
  ask fishes [
    ; Reset color first to handle priority of conditions
    set color blue

    ; Apply colors based on various conditions (in order of priority)
    if health < 50 [ set color gray ]
    if oxygen < 3 [ set color yellow ]
    if temperature > 30 [ set color orange ]
    if pollution > seuil_de_pollution [ set color red ]
  ]

  ; Update display based on action-count (special actions)
  if action-count = 1 [
    ask patches [ set pcolor blue ]
    output-print "Lac devenu bleu après traitement de l'eau."
  ]
  if action-count = 2 [
    ask patches [ set pcolor scale-color brown pollution 0 seuil_de_pollution ]
    output-print "Lac devenu brun après ajout d'éléments chimiques."
  ]
  if action-count = 3 [
    ask patches [ set pcolor green ]
    output-print "Lac devenu vert après ajout de poissons."
  ]
  if action-count = 4 [
    ask patches [ set pcolor turquoise ]
    output-print "Lac devenu turquoise après ajustement de la température."
  ]

  ; Ensure plants are properly displayed
  ask plants [
    set color green
    set size 1
  ]
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
  if health <= 0 [
    die
    set dead-fish dead-fish + 1
    set living-fish living-fish - 1
  ]
end

to wait-for-action [filename]
  let max-wait 30
  let waited 0
  while [not file-exists? filename and waited < max-wait] [
    wait 0.1
    set waited waited + 0.1
  ]
  if not file-exists? filename [
    output-print "Erreur : ppo_action.csv n’a pas été créé dans le temps imparti."
  ]
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

to-report read-number [x]
  if is-number? x [ report x ]
  if is-string? x [
    if (x = "" or x = "NA") [ report 0 ]
    let cleaned replace-comma-with-dot x
    let number read-from-string cleaned
    ifelse is-number? number [ report number ] [ report 0 ]
  ]
  report 0
end

to update-environment
  let row item current-line data-lines
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
  set water-quality read-number item 10 row

  ; Update global variables with current values
  set temperature temp-csv
  set turbidity turb-csv
  set oxygen oxy-csv
  set co2 co2-csv
  set ph ph-csv
  set alkalinity alk-csv
  set ammonia amm-csv
  set nitrite nit-csv
  set phosphorus phos-csv
  set plankton plank-csv
  set pollution temp-csv

  set bod 6
  set hardness 0
  set calcium 0
  set h2s 0

  ; Write current state to env_state.csv
  let env_state_file "C:/Users/Hp/Desktop/AquaSim-Innovators/env_state.csv"
  if file-exists? env_state_file [
    file-delete env_state_file
  ]
  csv:to-file env_state_file (list
    (list "turbidity" "temperature" "oxygen" "alkalinity" "ph" "ammonia" "phosphorus" "plankton" "nitrite" "co2" "current_line")
    (list turbidity temperature oxygen alkalinity ph ammonia phosphorus plankton nitrite co2 current-line)
  )
  output-print (word "Données environnementales écrites dans " env_state_file " (ligne " current-line ")")

  if pollution > 50 [
    output-print "Pollution trop haute! Traitement de l'eau déclenché."
    set oxygen oxygen + 2
  ]
  if oxygen < 3 [
    output-print "Alerte: Manque d'oxygène! Les poissons sont en danger."
    ask fishes [
      set health health - 10
      if health <= 0 [
        die
        set dead-fish dead-fish + 1
        set living-fish living-fish - 1
      ]
    ]
  ]
  if pollution > 80 [
    output-print "Alerte: Pollution extrême! Les poissons meurent."
    ask fishes [
      set health health - 20
      if health <= 0 [
        die
        set dead-fish dead-fish + 1
        set living-fish living-fish - 1
      ]
    ]
  ]
  if temperature > 30 [
    output-print "Température trop élevée! Risque de stress pour les poissons."
  ]
end

to apply-ppo-action
  file-open "ppo_action.csv"
  let action-list []
  while [not file-at-end?] [
    let action file-read-line
    set action-list lput action action-list
  ]
  file-close

  let action-item first action-list
  output-print (word "Action PPO reçue : " action-item)
  if action-item = "1" or action-item = "action1" [ set action-count action-count + 1 output-print "Action 1 exécutée." ]
  if action-item = "2" or action-item = "action2" [ set action-count action-count + 1 output-print "Action 2 exécutée." ]
  if action-item = "3" or action-item = "action3" [ set action-count action-count + 1 output-print "Action 3 exécutée." ]
  if action-item = "4" or action-item = "action4" [ set action-count action-count + 1 output-print "Action 4 exécutée." ]
end

to search-for-plants
  let nearby-plants plants in-radius 2
  if any? nearby-plants [
    let target-plant one-of nearby-plants
    ask target-plant [
      set health health + 5
      die
    ]
  ]
end

to move
  rt random-float 30 - random-float 30
  fd 1
end

to grow-plants
  if random 100 < 5 [
    create-plants 1 [
      setxy random-xcor random-ycor
      set color green
      set health 100
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
136
60
200
93
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
131
134
194
167
Go
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

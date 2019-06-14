extensions [gis r]
globals [budget ;; budget used in each period for agri-environmental payments
  landscape ;; information from a raster file (initial land-use allocation)
  soil-quality ;; information from a raster file (fertility)
  landuse_final ;; raster file to be exported at the end of simulation for R-based analysis
]
turtles-own [my-land ;; plots owned by farmer
  total-yield ;; sum of yields of all plots owned by farmer
  income ;; income from yields and payments received
]
patches-own [owned-by ;; determines who the plot belongs to
  my-neighbors ;; neighbouring plots owned by self farmer
  ascii-val ;; values from LANDSCAPE raster
  cover ;; whether patch is grassland or river (from ascii file)
  fertility ;; soil fertility of plot
  profit-ext ;; potential profit given extensive management
  profit-int ;; potential profit given intensive management
  dist-river ;; reports distance to river
  agg ;; reports the share of neighbouring plots that were managed extensively in previous period (for agg bonus)
  manag ;; management chosen for plot (intensive or extensive)
  yield ;; actual yield given management
  profit ;; realized profit of plot
]

to setup
  ca
  set landscape gis:load-dataset "models_data/landuse_rand.asc"
  set soil-quality gis:load-dataset "models_data/soil_fertility.asc"
  gis:apply-raster landscape ascii-val
  gis:apply-raster soil-quality fertility
  define-land-cover
  ;; create turtle
  set-default-shape turtles "person"
  ask one-of patches with [cover = "grass"] [
    sprout 1
  ]
  assign-plots
  check-agg
  reset-ticks
end

to define-land-cover
  ;; define river
  ask patches with [ascii-val = 3] [
    set cover "river"
    set pcolor blue
  ]
  ;; define grassland
  ask patches with [ascii-val = 1] [
    set cover "grass"
    set manag "ext"
    set pcolor green
  ]
  ask patches with [ascii-val = 2] [
    set cover "grass"
    set manag "int"
    set pcolor yellow
  ]
  ;; set attributes for all patches that are grassland
  ask patches with [cover = "grass"] [
    set yield 0
    set profit-ext 0
    set profit-int 0
    set agg 0
    ;; set distance to river
    set dist-river distance min-one-of patches with [cover = "river"] [distance myself]
  ]
end

to assign-plots
  ;; assign plots to turtle
  ask turtles [
    ask patches with [cover = "grass"] [
      set owned-by myself
    ]
    set my-land patches with [owned-by = myself]
  ]
  ;; set MY-NEIGHBORS
  ask patches [
    set my-neighbors neighbors with [owned-by = [owned-by] of myself]
  ]
end

to check-agg
  ;; different levels of agg-payment dependent on different shares of neighbours with extensive management
  ask patches [
    set agg count neighbors with [manag = "ext"] / 8
  ]
end

to go
  ask turtles [
    calc-pot-profit
    set-manag
    update-manag
  ]
  calc-yield
  check-agg
  ask turtles [
    calc-profit
    yield-income
  ]
  evaluate
  tick
end

to calc-pot-profit
  ;; We assume that the market price of grass is 1 and costs are 0 (so that yield = income without agri-env payments).
  ;; calculate potential profits for each management variant (for each plot separately)
  ask my-land [
    set profit-ext (1.5 * (1 + fertility)) ^ 0.5 + base-p + bonus-wat / dist-river + bonus-agg * agg
    set profit-int (2 * (1 + fertility)) ^ 0.5
  ]
end

to set-manag
  ;; set manag based on most profitable option and colour plots accordingly
  ask my-land [
    if profit-int < profit-ext [
      set manag "ext"
      set pcolor green
    ]
    if profit-int > profit-ext [
      set manag "int"
      set pcolor yellow
    ]
  ]
end

to update-manag
  ;; correct for neighboring own plots with profit potential if both extensive
  ask my-land with [manag = "int"] [
    ask my-neighbors with [manag = "int"] [
      if 0.25 * bonus-agg > (([profit-int] of self - [profit-ext] of self) + ([profit-int] of myself - [profit-ext] of myself)) [
        set manag "ext"
        set pcolor green
        ask myself [
          set manag "ext"
          set pcolor green
        ]
      ]
    ]
  ]
end

to calc-yield
  ;; calculate realized yields
  ask patches with [manag = "ext"] [
    set yield (1.5 * (1 + fertility)) ^ 0.5
  ]
  ask patches with [manag = "int"] [
    set yield (2 * (1 + fertility)) ^ 0.5
  ]
end

to calc-profit
  ;; calculate realized profit for each plot
  ask my-land [
    ifelse manag = "ext" [
      set profit yield + base-p + bonus-wat / dist-river + bonus-agg * agg
    ][
      set profit yield
    ]
  ]
end

to yield-income
  ;; calculate total yield and total income for each farmer
  set total-yield sum [yield] of my-land
  set income sum [profit] of my-land
end

to evaluate
  check-budget
  ;; R models only needed at end of run (here: 50 ticks)
  if (ticks = 49) [
    raster
    R-yield
    R-habitat
    R-water
  ]
end

to check-budget
  ;; calculate budget used to agri-environmental payments
  set budget (sum [income] of turtles - sum [total-yield] of turtles)
end

to raster
  ;; translate land-use pattern in ascii raster
  ask patches with [cover = "grass"] [
    ifelse manag = "ext" [
      set ascii-val 1
    ][
      set ascii-val 2
    ]
  ]
  ask patches [
    set landuse_final gis:patch-dataset ascii-val
  ]
  ;; LIMITATION: because in each BehaviorSpace run a newly generated LANDUSE_FINAL raster must be evaluated by R models, parallel runs are not possible
  gis:store-dataset landuse_final "landuse_final"
end

to R-yield
  ;; run yield model for landscape
  ;; note: yield is normalized here and thus doesn't equal yield calculated by CALC-YIELD (but is its linear transformation)
  ;; .libPaths() must be set as NetLogo usually only draws upon the non-writable R library folder
  r:eval ".libPaths(c('C:/Users/bartkows/Documents/R/win-library/3.5',.libPaths()))"
  r:eval "source('C:/Users/bartkows/Documents/Papers/2019 Social ecological optimization IP/Model/models_data/AY_test.R')"
end

to R-habitat
  ;; run habitat model for landscape
  r:eval ".libPaths(c('C:/Users/bartkows/Documents/R/win-library/3.5',.libPaths()))"
  r:eval "source('C:/Users/bartkows/Documents/Papers/2019 Social ecological optimization IP/Model/models_data/HI_test.R')"
end

to R-water
  ;; run water quality model for landscape
  r:eval ".libPaths(c('C:/Users/bartkows/Documents/R/win-library/3.5',.libPaths()))"
  r:eval "source('C:/Users/bartkows/Documents/Papers/2019 Social ecological optimization IP/Model/models_data/WQ_test.R')"
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
668
469
-1
-1
30.0
1
10
1
1
1
0
0
0
1
-7
7
-7
7
1
1
1
ticks
30.0

BUTTON
21
42
84
75
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
99
42
162
75
NIL
go\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
14
90
186
123
base-p
base-p
0
0.25
0.12
0.01
1
NIL
HORIZONTAL

SLIDER
15
141
187
174
bonus-agg
bonus-agg
0
0.25
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
13
191
185
224
bonus-wat
bonus-wat
0
0.25
0.25
0.01
1
NIL
HORIZONTAL

PLOT
699
10
1014
228
Mean yields
ticks
yield
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [total-yield] of turtles"

PLOT
1028
10
1361
230
Mean incomes
ticks
income
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [income] of turtles"

PLOT
697
248
1012
450
Budget
ticks
budget
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot budget"

PLOT
1027
248
1361
450
Extensive land
ticks
share extensive land
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count patches with [manag = \"ext\"] / count patches with [cover = \"grass\"]"

SLIDER
13
231
185
264
dist
dist
0
2
1.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This is a modification of a very simple model that aims to demonstrate the influence of agri-environmental payments on land-use patterns in a virtual landscape. The modification against the basic model is that there is only one agent and payment functions follow ecological outcome functions as closely as possible. The landscape consists of grassland (which can be managed extensively or intensively) and a river. Agri-environmental payments (BASE-P) are provided for extensive management of grassland. Additionally, there are boni for (a) extensive grassland in proximity of the river (BONUS-WAT); and (b) clusters ("agglomerations") of extensive grassland (BONUS-AGG). The 10 farmers, who own randomly distributed grassland patches, make decisions on the basis of simple income maximization. The resulting landscape pattern is evaluated by means of three simple models for (a) agricultural yield (R-YIELD), (b) habitat/biodiversity (R-HABITAT) and (c) water quality (R-WATER). The latter two correspond to the two boni.

## HOW IT WORKS

An agent (FARMER) compares potential income from each patch she owns for intensive vs. extensive management (given agri-environmental payments and last period's land-use pattern). She chooses the management that maximizes income and applies it accordingly. The assumed price of a unit of grass (product of grasslands) is 1, so that YIELD equals income (PROFIT) per patch in the absence of agri-environmental payments.

1. Initialization: import raster files and translate them into patch attributes
2. Potential profit calculation: calculate potential profit for each patch (intensive & extensive) given current land allocation and including base payment and boni
3. Allocation: allocate management to patch (extensive vs intensive)
4. Yield calculation: calculate each patch’s yield given allocation
5. Agglomeration: check how many neighbouring patches are managed extensively
6. Reception of payments: calculate payments received by each patch
7. Calculation of income: calculate total yield and income for each farm
8. Calculation of agri-environmental payment budget
9. Evaluate ES: translate landscape configuration into ES realizations (R models)

## HOW TO USE IT

BASE-P sets the level of the base payment
BONUS-AGG sets the level of the agglomeration bonus
BONUS-WAT sets the level of the water quality bonus
DIST sets the distance from the river of the patches that receive BONUS-WAT

MEAN YIELDS plot reports the mean yield of the landscape's patches
MEAN INCOMES plot reports the mean income derived by each farmer
BUDGET plot reports the overall sum of payments received by the farmers
EXTENSIVE LAND plot reports the share of extensive patches relative to all grassland patches

## THINGS TO NOTICE

Yellow patches are intensively managed, green ones are extensive.

## THINGS TO TRY

Move sliders setting the levels of payments and notice the resulting extent of land-use change and the duration until an equilibrium is reached.

## EXTENDING THE MODEL

Possible changes and extensions:
* interactions among farmers going beyond simple reactions to last period's land allocation (e.g. cheap talk, side payments...)
* more land-use options (e.g. arable land, agroforestry, forest)
* behaviourally heterogeneous farmers
* additional policy instruments (e.g. zoning)
* more complex evaluation models (e.g. biodiversity also based on margins)

## NETLOGO FEATURES

Model im- and exports raster files needed for the evaluation models run in R; thus, it also uses R and GIS extensions.

## RELATED MODELS

NA

## CREDITS AND REFERENCES

NA (to be updated)
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
NetLogo 6.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="MAGENTA_experiment_v1" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <final>r:stop</final>
    <timeLimit steps="50"/>
    <metric>budget</metric>
    <metric>r:get "ay.sum"</metric>
    <metric>r:get "hi"</metric>
    <metric>r:get "wq"</metric>
    <steppedValueSet variable="bonus-agg" first="0" step="0.01" last="0.25"/>
    <steppedValueSet variable="base-p" first="0" step="0.01" last="0.25"/>
    <steppedValueSet variable="bonus-wat" first="0" step="0.01" last="0.25"/>
    <enumeratedValueSet variable="dist">
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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

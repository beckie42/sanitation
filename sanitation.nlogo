extensions [table]

breed [people person]

people-own [
  resources
  similar
  happy?
  health-desire
  status-desire
  health-seeker?
  resources-sign
  high-status?
]

patches-own [
  status
  elev-status
  available?
  improved?
]

globals [
  equilibrium?
  moves
  recent-happiness
  gif?
  start-happy
  end-happy
  goal-y
  goal-x
  correlation-y?
  correlation-x?
]

to setup
  set gif? False
  clear-all
  setup-people-random
  update-patches
  update-people
  reset-ticks
end

to go
  move-unhappy-people
  update-people
  update-patches
  tick
  if gif? = True
    [ export-view (word "sanitation" (word ticks ".png")) ]
end

to setup-people-random
  let population world-width * world-height
  ask n-of population patches [sprout-people 1 
    [
      set shape "circle"
      set resources random-normal 0 20
      ifelse resources >= 0
        [ set resources-sign "+" ]
        [ set resources-sign "-" ]
      set health-desire random-normal 30 20
      set status-desire random-normal 50 10
      ifelse health-desire > (z-health-seekers * 20 + 30)
        [ set health-seeker? True
          set shape "triangle" 
          ]
        [ set health-seeker? False ]
       
      let c (resources + 75) / 150
      if c != 1 and c != 0 and c != 0.5 and c > 0 and c < 1
        [ ifelse c > 0.5
          [ set c (1 - (1 - c) ^ 1.5) ]
          [ set c c ^ 1.5 ]
        ]
      let r median (list 255 (255 - (255 - 82) * c) 82)
      let g median (list 255 (225 - (255 - 0) * c) 0)
      let b median (list 255 (255 - (255 - 82) * c) 99)
      set color (list r g b)
    ]
  ]
end

to update-patches
  ask patches [
    let statusref [resources] of turtles-here
    let neighbours (turtles-on neighbors)
    set status (mean [resources] of neighbours)
    
    ifelse status > cost-threshold and count neighbours with [health-seeker? = True] >= activist-threshold
      [ set improved? True
        set pcolor green ]
      [ set improved? False ]
  ]
end
  
to update-people
  let rankedpeople sort-on [(- resources)] people
  let cutoff (precision (%highstatus / 100 * count people) 0)
  ask people [
    ifelse (position self rankedpeople) < cutoff
      [ set high-status? True ]
      [ set high-status? False ]
  ]
  
  let hspeople people with [high-status? = True]
  let non-hspeople people with [high-status? = False]
  
  ask people [
    ifelse health-seeker?
    [ ifelse [improved?] of patch-here = True and [status] of patch-here >= resources
      [ set happy? True ]
      [ set happy? False ]
    ]
    [ ifelse [status] of patch-here >= resources
      [ set happy? True ]
      [ set happy? False ] 
    ]
  ]
  
end

to move-unhappy-people
  set moves 0
  let unhappypeople people with [happy? = False]
  ask unhappypeople [ ask patch-here [ set available? True ] ]
  let availablepatches []
  
  ifelse move-happy? 
    [ set availablepatches patches ]
    [ set availablepatches patches with [available? = True] ]
  
  let rankedpatches []
  
  set unhappypeople sort-on [(- resources)] unhappypeople                                                                   
  foreach unhappypeople [ ask ? 
    [  
      if patchranking = "status"
        [ ifelse health-seeker?
          [ let rankedpatchset availablepatches in-radius move-distance
            set rankedpatches sort-by [
            ([improved?] of ?1 = True and [improved?] of ?2 = False) or 
            ([improved?] of ?1 = [improved?] of ?2 and [status] of ?1 > [status] of ?2) 
            ] rankedpatchset ] 
          [ let rankedpatchset availablepatches in-radius move-distance
            set rankedpatches sort-on [(- status)] rankedpatchset ]
          ]
      
;      show rankedpatches
      let partner best-partner self rankedpatches
      
      if partner != nobody [
        let partnerpatch [patch-here] of partner
        ask partnerpatch [set available? False]
        set availablepatches patches with [available? = True]
      
        let currentpos patch-here
        let newpos [patch-here] of partner
        move-to newpos
        ask partner [ move-to currentpos ]
        set moves moves + 1
      ]
        
      ]
    ]
end

to-report best-partner [thisperson thispatchlist] 
  if choose-partner = "resources&distance"
    [ let d max-pxcor * 4
      foreach thispatchlist [
        let partner one-of turtles-on ? 
        ask thisperson [
          set d distance partner
        ]
        if d <= move-distance and ([happy?] of partner = False or resources > [resources] of partner)
          [ report partner ]
      ]
    ] 
  report nobody
end

to gif
  setup
  set gif? True
  export-view (word "sanitation" (word ticks ".png"))
  while [ticks < 101]
    [ go ]
  set gif? False
end
@#$#@#$#@
GRAPHICS-WINDOW
1045
10
1383
369
20
20
8.0
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
20
19
87
52
NIL
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
92
19
155
52
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
20
73
214
106
z-health-seekers
z-health-seekers
-4
4
1
.1
1
NIL
HORIZONTAL

PLOT
14
587
343
737
% happy
time
%
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"all people" 1.0 0 -817084 true "" "plot count people with [ happy? = True ] / count people * 100"
"red people" 1.0 0 -2674135 true "" "plot count people with [ happy? = True and resources < 0] / count people with [ resources < 0 ] * 100"
"green people" 1.0 0 -13840069 true "" "plot count people with [ happy? = True and resources >= 0] \n/ count people with [ resources >= 0 ] * 100"

MONITOR
13
193
96
246
red %
count people with [resources < 0] / count people * 100
2
1
13

MONITOR
124
199
225
252
happy %
count people with [happy? = True] / count people * 100
2
1
13

MONITOR
14
325
127
378
mean similarity
mean [similar] of people
2
1
13

MONITOR
14
261
111
314
- happy
count people with [happy? = True and resources < 0]
0
1
13

MONITOR
122
261
235
314
+ happy
count people with [happy? = True and resources >= 0]
0
1
13

PLOT
14
384
214
534
similarity of neighbours
time
% similar
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"% similar" 1.0 0 -13345367 true "" "plot mean [similar] of people"

PLOT
239
387
439
537
number of moves
tick
moves
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -13345367 true "" "plot moves"

PLOT
366
589
566
739
elevation 
time
elevation
0.0
10.0
-5.0
5.0
true
true
"" ""
PENS
"red people" 1.0 0 -2674135 true "" "plot mean [ycor] of people with [resources < 0]"
"green people" 1.0 0 -13840069 true "" "plot mean [ycor] of people with [resources >= 0]"

MONITOR
248
260
388
313
mean red elevation
mean [ycor] of people with [resources < 0]
2
1
13

MONITOR
249
322
405
375
mean green elevation
mean [ycor] of people with [resources >= 0]
2
1
13

MONITOR
14
124
160
177
% health seekers
(count people with [health-seeker? = True] / count people) * 100
0
1
13

CHOOSER
257
10
437
55
patchranking
patchranking
"status" "elevationanywhere" "elevationneighbours" "elevationdistance" "elev-statusfunction" "none" "status-associated"
0

CHOOSER
257
64
435
109
choose-partner
choose-partner
"free" "resourcesgreater" "withindistance" "elev-statusfunction" "resources&distance"
4

PLOT
651
498
851
648
resources
NIL
NIL
-100.0
100.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [resources] of people"

MONITOR
739
425
845
478
min resources
min [resources] of turtles
2
1
13

MONITOR
866
425
976
478
max resources
max [resources] of turtles
2
1
13

SLIDER
491
143
663
176
move-distance
move-distance
0
10
4
1
1
NIL
HORIZONTAL

PLOT
593
675
793
825
 desires
NIL
NIL
-100.0
100.0
0.0
10.0
true
true
"" ""
PENS
"health" 1.0 1 -16777216 true "" "histogram [health-desire] of turtles"
"status" 1.0 1 -7500403 true "" "histogram [status-desire] of turtles"

SWITCH
494
33
638
66
move-happy?
move-happy?
0
1
-1000

SLIDER
698
21
870
54
el-ceiling
el-ceiling
0
2
1
.01
1
NIL
HORIZONTAL

SLIDER
697
68
869
101
el-floor
el-floor
0
2
0.48
.01
1
NIL
HORIZONTAL

MONITOR
857
570
991
623
mean resources 4
mean [resources] of people with [pycor > max-pycor / 2]
2
1
13

MONITOR
857
630
989
683
mean resources 3
mean [resources] of people with [pycor > 0 and pycor <= max-pycor / 2]
2
1
13

MONITOR
857
690
987
743
mean resources 2
mean [resources] of people with [pycor <= 0 and pycor > (- max-pycor) / 2]
2
1
13

MONITOR
859
754
991
807
mean resources 1
mean [resources] of people with [pycor <= (- max-pycor) / 2]
2
1
13

SLIDER
701
112
873
145
c2
c2
0
1
1
.01
1
NIL
HORIZONTAL

SLIDER
701
153
873
186
f2
f2
0
1
1
.01
1
NIL
HORIZONTAL

SLIDER
491
98
663
131
%highstatus
%highstatus
0
100
20
1
1
NIL
HORIZONTAL

SLIDER
702
209
874
242
hs-diff
hs-diff
0
10
2
1
1
NIL
HORIZONTAL

SLIDER
703
256
875
289
hs-c
hs-c
-2
2
1
.01
1
NIL
HORIZONTAL

SLIDER
704
302
876
335
hs-f
hs-f
-2
2
0
.01
1
NIL
HORIZONTAL

MONITOR
858
502
961
555
correlation-y?
correlation-y?
17
1
13

MONITOR
865
363
922
416
goal-y
goal-y
2
1
13

BUTTON
167
20
230
53
gif
gif
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
255
129
427
162
cost-threshold
cost-threshold
-100
100
2
1
1
NIL
HORIZONTAL

SLIDER
257
177
429
210
activist-threshold
activist-threshold
0
9
2
1
1
NIL
HORIZONTAL

SLIDER
496
197
668
230
distpenalty
distpenalty
0
2
1.25
.01
1
NIL
HORIZONTAL

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

sun
false
0
Circle -7500403 true true 75 75 150
Polygon -7500403 true true 300 150 240 120 240 180
Polygon -7500403 true true 150 0 120 60 180 60
Polygon -7500403 true true 150 300 120 240 180 240
Polygon -7500403 true true 0 150 60 120 60 180
Polygon -7500403 true true 60 195 105 240 45 255
Polygon -7500403 true true 60 105 105 60 45 45
Polygon -7500403 true true 195 60 240 105 255 45
Polygon -7500403 true true 240 195 195 240 255 255

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
NetLogo 5.0.4
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

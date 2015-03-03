extensions [table]

breed [people person]

people-own [
  resources
  similar
  happy?
  health-desire
  status-desire
  health-seeker?
  green-seeker?
  resources-sign
  high-status?
  checked?
  clusterset?
]

patches-own [
  status
  score
  g-score
  g-neighbours
  available?
  improved?
]

globals [
  moves
  gif?
  correlation-g?
  adjcluster
  not-checked
]

to setup
  clear-all
  set gif? False
  set correlation-g? False
  setup-people-random
  update-patches
  update-people
  reset-ticks
end

to go
  if count patches with [pcolor != green] > 0
    [
      move-unhappy-people
      update-people
      update-patches
      tick
      if gif? = True
        [ export-view (word "sanitation" (word ticks ".png")) ]
    ]
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
      
      ;;; designate individuals with health-desire above the threshold as health-seekers
      ifelse health-desire > (z-health-seekers * 20 + 30)
        [ set health-seeker? True
          set shape "triangle" 
          ]
        [ set health-seeker? False ]
        
      ;;; nobody is a green-seeker initially
      set green-seeker? False
       
      ;;; set turtle colour range from light to dark purple, based on resources
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
      
      set checked? False
    ]
  ]
end

to update-patches
  ask patches [
    ;;; set status of patches based on resources of neighbours
    let statusref [resources] of turtles-here
    let neighbours (turtles-on neighbors)
    set status (mean [resources] of neighbours)
    set g-neighbours count neighbours with [pcolor = green]
    set score 0
    ifelse pcolor = green
      [ set g-score 1 ]
      [ set g-score 0 ]
  ]
end
  
to update-people
  ;;; identify high status people based on resources
  let rankedpeople sort-on [(- resources)] people
  let cutoff (precision (%highstatus / 100 * count people) 0)
  ask people [
    ifelse (position self rankedpeople) < cutoff
      [ set high-status? True ]
      [ set high-status? False ]
  ]
  
  let hspeople people with [high-status? = True]
  let non-hspeople people with [high-status? = False]
  
  ;;; identify clusters of health-seekers and determine whether they have sufficient resources to take action
  let activists people with [health-seeker? = True]
  ask activists
    [ if checked? = False
        [ let cluster (find-adjacent self activists)
          foreach cluster
            [ ask ?
              [ set clusterset? True
                set checked? True ]
            ]
          let clusterset people with [clusterset? = True]
;          if mean [resources] of clusterset > cost-threshold
          if sum [resources] of clusterset > sum-threshold
            [ ask clusterset
              [ ask patch-here 
                  [ set pcolor green ]
                ask neighbors
                  [ set pcolor green ] 
              ]
            ]
          ask clusterset [ set clusterset? False ]
        ]
    ]    
  
  ;;; update happiness
  ask people [
    ;;; health seekers are happy when on a green patch
    ifelse health-seeker?
      [ ifelse [pcolor] of patch-here = green
        [ set happy? True ]
        [ set happy? False ]
      ]
    
      ;;; for green seekers, being on a green patch can make up for g-compensation in status
      [ ifelse green-seeker?
        [ ifelse [pcolor] of patch-here = green
          [ ifelse [status] of patch-here + g-compensation >= resources
              [ set happy? True ]
              [ set happy? False ]
            ]
          [ ifelse [status] of patch-here >= resources
            [ set happy? True ]
            [ set happy? False ]
            ]
        ]
      
        ;;; if green is correlated with high status, being on a green patch can make up for some status for all status seekers
        ;;; the amount by which a green patch can compensate is the mean difference in resources between people on green and non-green patches
        [ ifelse correlation-g? = True
          [ let g-comp (mean [resources] of people with [[pcolor] of patch-here = green] - mean [resources] of people with [[pcolor] of patch-here != green])
            ifelse [pcolor] of patch-here = green
            [ ifelse [status] of patch-here + g-comp >= resources
              [ set happy? True ]
              [ set happy? False ]
            ]
            [ ifelse [status] of patch-here >= resources
              [ set happy? True ]
              [ set happy? False ]
            ]
          ]
          ;;; otherwise, status seekers are happy when on a patch with status greater than their own resources
          [ ifelse [status] of patch-here >= resources
            [ set happy? True ]
            [ set happy? False ]
          ] 
        ]
      ]
    set checked? False
  ]
  
  ;;; check whether green is associated with status
  if count patches with [pcolor = green] > 0
    [ let g people with [[pcolor] of patch-here = green]
      let notg people with [[pcolor] of patch-here != green]
      if count notg > 0
        [ ifelse abs (mean [resources] of g - mean [resources] of notg) > diff
          [ set correlation-g? True ]
          [ set correlation-g? False ]
        ]
      
      ;;; check whether non-health-seekers on green patches convert to green-seekers  
      ask g
        [ if health-seeker? = False
          [ if random 100 < conversion-chance
            [ set green-seeker? True 
              set shape "star" 
;              ask neighbors
;                [ set pcolor green ]
            ]
          ]
        ]
    ]
  
end

;;; given a person in the set "similarpeople", report a list of that person's neighbours who are also in the set "similarpeople"
to-report find-adjacent [thisperson similarpeople]
  set adjcluster (list thisperson)
  set not-checked (list thisperson)
  while [length not-checked > 0]
    [ foreach not-checked
      [ let matchingneighbours match-neighbours ? similarpeople
        set adjcluster sentence adjcluster matchingneighbours
        set not-checked sentence not-checked matchingneighbours
        set not-checked remove ? not-checked
      ]
    ]
  report adjcluster
end
      
to-report match-neighbours [thisperson similarpeople]
  let matchingneighbours []
  ask [neighbors] of thisperson
    [ if member? (one-of turtles-here) similarpeople and not member? (one-of turtles-here) adjcluster
      [ set matchingneighbours sentence matchingneighbours (one-of turtles-here) ]
    ]
  report matchingneighbours
end

;;; people who are unhappy move to the best square they can afford (i.e., outbid for)
to move-unhappy-people
  ;;; only unhappy people move and have available patches
  set moves 0
  let unhappypeople people with [happy? = False]
  ask unhappypeople [ ask patch-here [ set available? True ] ]
  let availablepatches []
  
;  ifelse move-happy? 
;    [ set availablepatches patches ]
;    [ set availablepatches patches with [available? = True] ]
;  show [self] of availablepatches
  
  let rankedpatches []
  
  ;;; unhappy people move in descending order of resources
  set unhappypeople sort-on [(- resources)] unhappypeople                                                                   
  foreach unhappypeople [ ask ?
    ;;; people can move a maximum of move-distance from their current patch 
    [ let rankedpatchset patches with [distance ? <= move-distance]
      
    ;;; give each available patch a patch score based on the mover's preferences
    
    ;;; in general, patch score is status plus number of green neighbours plus a compensation score based on how much the mover cares about being on a green patch
    ;;; for health-seekers, the green compensation is 100
    ifelse health-seeker?
      [ ask rankedpatchset [ set score 100 * g-score + (g-neighbours * 100 / 9) + status ] ]
    
    ;;; for green-seekers, the green compensation is set by the g-compensation slider
      [ ifelse green-seeker? or correlation-g?
        [ ask rankedpatchset [ set score g-compensation * g-score + (g-neighbours * g-compensation / 9) + status ] ]
        
        ;;; for others, green compensation is 0          
        [ ask rankedpatchset [ set score status ] ]
      ]
      
    ;;; available patches are sorted by patch score
    set rankedpatches sort-on [(- score)] rankedpatchset
    
       
;      if patchranking = "status"
;        [ ifelse health-seeker? or correlation-g?
;          [ set rankedpatches sort-by [ ([pcolor] of ?1 = green and [pcolor] of ?2 != green) or ([pcolor] of ?1 = [pcolor] of ?2 and [status] of ?1 > [status] of ?2) 
;            ] rankedpatchset ] 
;          [ set rankedpatches sort-on [(- status)] rankedpatchset ]
;          ]
      
;      show rankedpatches
      let partner best-partner self rankedpatches
      
      if partner != nobody [
;        let partnerpatch [patch-here] of partner
;        ask partnerpatch [set available? False]
;        set availablepatches patches with [available? = True]
      
        let currentpos patch-here
        let newpos [patch-here] of partner
        move-to newpos
        ask partner [ move-to currentpos ]
        set moves moves + 1
      ]
        
      ]
    ]
;  ask patches [set available? True]
end


;;; report the owner of the best available patch for which the buyer can outbid the seller
to-report best-partner [thisperson thispatchlist] 
  if choose-partner = "resources&distance"
    [ let d max-pxcor * 4
      foreach thispatchlist [
        let partner one-of turtles-on ? 
        ask thisperson [
          set d distance partner
        ]
;        if d <= move-distance and ([happy?] of partner = False or resources > [resources] of partner)
        if d <= move-distance and (resources > [resources] of partner)
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
1303
289
15
15
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
-15
15
-15
15
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
"- resources" 1.0 0 -2674135 true "" "plot count people with [ happy? = True and resources < 0] / count people with [ resources < 0 ] * 100"
"+ resources" 1.0 0 -13840069 true "" "plot count people with [ happy? = True and resources >= 0] \n/ count people with [ resources >= 0 ] * 100"

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
"- resources" 1.0 0 -2674135 true "" "plot mean [ycor] of people with [resources < 0]"
"+ resources" 1.0 0 -13840069 true "" "plot mean [ycor] of people with [resources >= 0]"

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
482
119
654
152
move-distance
move-distance
0
10
2
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
482
74
654
107
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
diff
diff
0
10
2
1
1
NIL
HORIZONTAL

MONITOR
489
437
593
490
correlation-g?
correlation-g?
1
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
25
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
482
157
654
190
distpenalty
distpenalty
0
2
1.25
.01
1
NIL
HORIZONTAL

MONITOR
485
263
617
316
g mean resources
mean [resources] of people with [[pcolor] of patch-here = green]
2
1
13

MONITOR
487
330
632
383
non-g mean resources
mean [resources] of people with [[pcolor] of patch-here != green]
2
1
13

SLIDER
707
265
882
298
conversion-chance
conversion-chance
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
256
220
428
253
sum-threshold
sum-threshold
0
100
100
1
1
NIL
HORIZONTAL

SLIDER
483
203
655
236
g-compensation
g-compensation
0
100
30
1
1
NIL
HORIZONTAL

MONITOR
489
389
606
434
mean g advantage
mean [resources] of people with [[pcolor] of patch-here = green] - mean [resources] of people with [[pcolor] of patch-here != green]
2
1
11

@#$#@#$#@
## WHAT IS IT?

An individual can improve their health by taking health-directed action. However, other actions that are not intrinsically health-directed can also affect their health, e.g., moving to a "better" neighbourhood. These actions can work through spillover effects from the health-directed actions of other people. For example, if a small number of people care enough about improving their neighbourhood (and have sufficient resources) to contribute the initial costs, everyone living in that neighbourhood will benefit.
In addition, people may take action to acquire the same improvements for reasons other than health-seeking. For example, if a health-improving action becomes associated with high status, people who care about status, by taking status-direction actions, will also improve their health.

This model simulates the process by which a small initial number of wealthy health-seekers introducing an amenity (sanitation) to their neighbourhood leads to the widespread adoption of the amenity over time through status-seeking rather than health-directed action.

??? 
Should the initial introduction of the amenity require a specific sum, rather than mean, resources? (added that option)
- if using mean resources and converted green seekers don't automatically spread the improvement to their neighbours, the improvement never spreads beyond the high-status patches
- if using sum resources and converted green seekers don't automatically spread the improvement to their neighbours, the improvement does spread to all but the lowest status patches

Should people who are converted to green seekers really be treated the same as health seekers? Maybe they would be happy with either a lower-status green patch or a higher-status non-green patch. (true now)
- with this model, improvement does not spread beyond the high-status patches
- but there are pockets of lower-status green patches. Why don't high-resources health/green seekers take over?

Should living next to a green patch be worth something to green/health seekers?


## HOW IT WORKS

*INITIAL SETUP*

Each individual has a randomly assigned level of resources, health desire and status desire. These variables are normally distributed across the population. The mean status desire is greater than the mean health desire and has a smaller standard deviation. Turtles are coloured based on resources from light purple (lowest) to dark purple (highest).

The initial number of active health seekers is controlled by the z-health-seekers slider. This value indicates the z-score for health desire at which an individual starts attempting to take health-directed action. Individuals with health desire greater than this threshold are labelled "health seekers" and indicated by a triangle.

The percentage of people considered to be "high status" can be adjusted using the %high-status slider. The people within that top percentile for resources will be designated "high status". If a neighbourhood becomes associated with high-status people, status-seeking individuals will attempt to move into that neighbourhood.

Each patch has a "status" value equal to the mean resources of the people on (the patch and?) its 8 neighbours.

*HAPPINESS*

Health seekers are happy when they are living on an improved patch (indicated by green patch shading).

Status seekers are initially happy when they are living on a patch with greater status than their own resources.

Status seekers who are converted to green seekers are happy when living on a patch where the status plus the compensation provided by being on a green patch (set by the g-compensation slider) is greater than their own resources.

If living on a green patch becomes associated with status (i.e., the mean resources of people living on green patches is more than "diff" greater than the mean resources of people living on non-green patches), then status seekers will also get a status boost from living on an improved (green) patch. This boost is equivalent to the mean difference in status between people on green and non-green squares.

*NEIGHBOURHOOD IMPROVEMENTS*

The cost of implementing a health-directed improvemenet is set using the cost-threshold slider. If the mean resources of a cluster of contiguously located health-seekers is greater than the cost-threshold, the neighbourhood surrounding the cluster will be improved, i.e., all the patches comprising the cluster and each of their 9 neighbours will be coloured green.  

Non-health seekers living on improved patches may come to appreciate the benefits of the improvement and convert to being health-seekers (**NB change to "green seekers"?) themselves. The probability of doing so, once exposed to a green improved square, is set by the conversion-chance slider.

*MOVING*

People who are unhappy will try to move to a patch on which they will be happy. An unhappy person can force a happy person off their patch if the buyer has greater resources than the seller.

Move order is set by resources, with people having the opportunity to find a new patch in order of decreasing resources. No person can move more than the distance set by the "move-distance" slider.

The patches available to each person (i.e., those within move-distance) are ranked according to the happiness requirements of the buyer. For status seekers, the patches are ranked by status. For health seekers, all improved (green) patches are ranked by status, ahead of unimproved patches, which are also ranked by status. If improvements become associated with status, status seekers will be treated as health seekers.

A buyer finds a new patch to move to by checking the list of ranked available patches from most to least desirable until reaching one whose current owner has fewer resources than the buyer. The buyer and seller then swap patches. If a buyer does not find a patch whose owner they can outbid, the buyer will not move.

After every person has had the opportunity to move, the happiness of each person is updated, and if a neighbourhood now has sufficient resources, any new improvements are made. The status of each patch is also updated.

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
NetLogo 5.1.0
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


proc center_point(y0, y1, y2, y3: float): float =
  if (y0 == y2 and y1 == y3) or
     (y0 == y1 and y2 == y3)               : result = (y0 + y3) * 0.5
  elif y0 == y1 and y1 == y2 and y2 != y3  : result = y0
  elif y1 == y2 and y2 == y3 and y3 != y0  : result = y3
  elif y0 == y3                            : result = y0
  elif y1 == y2                            : result = (y0 + y3) * 0.5
  else                                     : result = (y0 + y1 + y2 + y3) / 4f

proc apply_too_high(y0, y1, y2, y3: var float): bool =
  const too_high = 4
  if   (y0 - y1) > too_high: y0 = y1 ; result = true
  elif (y1 - y0) > too_high: y1 = y0 ; result = true
  if   (y0 - y2) > too_high: y0 = y2 ; result = true
  elif (y2 - y0) > too_high: y2 = y0 ; result = true
  if   (y2 - y3) > too_high: y2 = y3 ; result = true
  elif (y3 - y2) > too_high: y3 = y2 ; result = true
  if   (y1 - y3) > too_high: y1 = y3 ; result = true
  elif (y3 - y1) > too_high: y3 = y1 ; result = true

const margin = 2047/2048f
proc cube_point_y*(level: Level, i,j,w: int): float =
  let vert = cube_verts[ cube_index[w] ]
  result = level.data[level.offset(i+vert.z.int, j+vert.x.int)] + vert.y.float * (1-margin)

  let m0 = level.map[i+0, j+0].cliffs
  let m1 = level.map[i+0, j+1].cliffs
  let m2 = level.map[i+1, j+0].cliffs
  let m3 = level.map[i+1, j+1].cliffs
  var m = level.map[i+vert.z.int, j+vert.x.int].cliffs #level.mask[level.offset(i+vert.z.int, j+vert.x.int)]

  proc apply_cliffs(y0, y1, y2, y3: var float): bool =
    if m.has JJ:
      y0 = y1
      y2 = y3
      result = true
    if m.has VV:
      y0 = y2
      y1 = y3
      result = true
    if m1.has LL:
      y1 = y0
      result = true
    if m3.has LL:
      y1 = y0
      y3 = y2
      result = true
    if m2.has AA:
      y2 = y0
      y3 = y1
      result = true
    if m3.has AA:
      y3 = y1
      result = true
    if m1.has(VV) and m2.has JJ:
      y0 = y3
      result = true

  var y0 = level.map[i+0, j+0].height + vert.y.float * (1-margin)
  var y1 = level.map[i+0, j+1].height + vert.y.float * (1-margin)
  var y2 = level.map[i+1, j+0].height + vert.y.float * (1-margin)
  var y3 = level.map[i+1, j+1].height + vert.y.float * (1-margin)
  var yc: float = 0

  let masks = level.map[i,j].masks

  if masks.has level.phase:
    y0 = 0 ; y1 = 0 ; y2 = 0 ; y3 = 0
  if RH in masks:
    result = 0 ; y0 = 0 ; y1 = 0 ; y2 = 0 ; y3 = 0

  var base: float = -2

  #if y0 != 0 and y3 != 0 and masks.has FL:
  base = result - 1.5

  if apply_too_high(y0, y1, y2, y3):
    base = -2
  if apply_cliffs(y0, y1, y2, y3):
    base = -2


  #if y0 == 0 or y1 == 0 or y2 == 0 or y3 == 0:
  #  y0 = base ; y1 = base ; y2 = base ; y3 = base

  if not level.map[i+0,j+0].masks.has(RH) and level.map[i+0,j+1].masks.has RH:
    y1 = y0
    y3 = y2

  yc = center_point(y0, y1, y2, y3)

  if vert.y == 0:                   result = base + margin * vert.y
  elif vert.z == 0 and vert.x == 0: result = y0
  elif vert.z == 0 and vert.x == 1: result = y1
  elif vert.z == 1 and vert.x == 0: result = y2
  elif vert.z == 1 and vert.x == 1: result = y3
  elif vert.z==0.5 and vert.x==0.5: result = yc


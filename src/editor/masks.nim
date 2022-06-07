
proc set_mask(editor: var Editor, mask: CliffMask) =
  var m = mask
  let o = editor.offset()
  let cur = editor.mask[o]
  if   cur == RH or cur == RI:
    if   mask == HH: m = RH
    elif mask == II: m = RI
    elif mask == GG: m = GR
  elif cur == BH or cur == BI:
    if   mask == HH: m = BH
    elif mask == II: m = BI
  elif cur == EY or cur == EM:
    if   mask == AA: m = EA
    if   mask == P1: m = EP
    if   mask == HH: m = EH
    if   mask == VV: m = EV
    if   mask == II: m = MI
    if   mask == BH: m = EB
  elif cur == OU:
    if   mask == II: m = OI
  elif cur == P1:
    if   mask == P1: m = P2
  elif cur == P2:
    if   mask == P1: m = P3
  elif cur == P3:
    if   mask == P1: m = P4
  elif cur == GG:
    if   mask == RH: m = GR
  elif cur == S1:
    if   mask == S1: m = S2
  elif cur.cliff():
    if cur == II and mask == NS:
      m = IN
    elif mask.cliff():
      m = CliffMask(cur.ord xor mask.ord)
    else:
      m = mask

  editor.level[editor.row, editor.col] = m
  editor.dirty.add (editor.row, editor.col)

  if m.zone or cur.zone:
    var current_zones = editor.level.zones
    var new_zones = editor.level.find_zones()
    editor.level.queue_update LevelUpdate(kind: Zones, zones: new_zones)

    for zone in current_zones:
      for i,j in editor.level.coords(zone):
        editor.dirty.add (i,j)
    for zone in new_zones:
      for i,j in editor.level.coords(zone):
        editor.dirty.add (i,j)

    for (i,j) in editor.dirty:
      editor.level.load_masks(new_zones, i,j)
  else:
    editor.level.load_masks(editor.level.zones, editor.row, editor.col)

  #if m.hazard:
  #  editor.level.queue_update LevelUpdate(kind: Actors, actors: editor.level.find_actors())

action:
  proc input_mask(editor: var Editor) =
    let mask = case editor.recent_input
    of GLFWKey.A : AA
    of GLFWKey.B : BH
    of GLFWKey.C : IC
    of GLFWKey.D : SD
    of GLFWKey.F : FL
    of GLFWKey.G : GG
    of GLFWKey.H : HH
    of GLFWKey.I : II
    of GLFWKey.J : JJ
    of GLFWKey.L : LL
    of GLFWKey.M : EM
    of GLFWKey.N : NS
    of GLFWKey.O : OU
    of GLFWKey.P : P1
    of GLFWKey.R : RH
    of GLFWKey.S : S1
    of GLFWKey.T : TU
    of GLFWKey.U : CU
    of GLFWKey.V : VV
    of GLFWKey.W : SW
    of GLFWKey.X : XX
    of GLFWKey.Y : EY
    else: return
    editor.set_mask mask


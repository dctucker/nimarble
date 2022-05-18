import macros

macro cliff_masks(body: untyped): untyped =
  body.expectKind nnkStmtList
  var fields: seq[NimNode] = @[]
  var names: seq[string] = @[]
  for n,b in body.pairs:
    case b.kind
    of nnkAsgn:
      fields.add newTree(nnkEnumFieldDef, b[0], b[1][0])
      names.add b[1][1].strVal
    of nnkCommand:
      fields.add b[0]
      names.add b[1].strVal
    else:
      b.expectKind nnkCommand
  result = newStmtList(
    newEnum(newIdentNode("CliffMask"), fields.openArray, true, false),
    newLetStmt(newIdentNode("cliff_mask_names"), newLit(names))
  )
  #echo $result.repr

cliff_masks:
  XX = 0  "regular slope"
  LL = 1  "left"
  JJ = 2  "right"
  HH      "horizontal"
  AA = 4  "up"
  LA      "left+up"
  AJ      "up+right"
  AH      "up+horizontal"
  VV = 8  "down"
  LV      "left+down"
  VJ      "down+right"
  VH      "down+horizontal"
  II      "vertical"
  IL      "vertical+left"
  IJ      "vertical+right"
  IH = 15 "oops! all cliffs"
  RI      "ramps up/down"
  RH      "left/right"
  NS      "no slope"
  GR      "guard rail"
  FL      "flag"
  GG      "goal"
  TU      "tube"
  IN      "portal in"
  OU      "portal out"
  MI      "mini"
  IC      "icy"
  CU      "copper"
  OI      "oil"
  SD      "sand"
  BH      "bumpy horizontal"
  BI      "bumpy vertical"
  SW      "sine wave"
  PH      "phased blocks"
  P1      "player 1 start position"
  P2      "player 2 start position"
  EA      "entity: acid"
  EM      "entity: marble"
  EV      "entity: vacuum"
  EP      "entity: piston"
  EH      "entity: hammer"
  EB      "entity: bird"
  EY      "entity: yum"

proc name*(mask: CliffMask): string =
  return cliff_mask_names[mask.ord]

proc cliff*(a: CliffMask): bool =
  return XX.ord < a.ord and a.ord <= IH.ord

proc has*(a,b: CliffMask): bool =
  result = a == b
  if a.cliff and b.cliff:
    return (a.ord and b.ord) != 0

proc `or`*(m1, m2: CliffMask): CliffMask =
  return CliffMask( m1.ord or m2.ord )

proc `+=`*(m: var CliffMask, m2: CliffMask) =
  m = m or m2

proc rotate*(mask: CliffMask): CliffMask =
  if mask.cliff:
    if mask.has LL: result += AA
    if mask.has AA: result += JJ
    if mask.has JJ: result += VV
    if mask.has VV: result += LL
  else:
    result = mask

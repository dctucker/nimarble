
const default_texture = 0

proc mask_texture*(level: Level, masks: set[CliffMask]): int =
  if TU in masks: return TU.ord
  for mask in masks:
    if mask.cliff(): continue
    return mask.ord

proc point_texture(level: Level, i,j: int): int =
  let k = level.width * i + j
  if k >= level.data.len: return
  let y = level.data[k]
  if y == EE: return

  let masks = level.map[i,j].masks
  if IC in masks: return IC.ord
  if CU in masks: return CU.ord
  if SD in masks: return SD.ord
  if BI in masks: return BI.ord
  if BH in masks: return BH.ord
  if OI in masks: return OI.ord
  if MI in masks: return MI.ord
  if {P1,P2,P3,P4} * masks != {}:
    return P1.ord

  return level.mask_texture(masks)

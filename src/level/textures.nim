
const default_texture = 0

proc mask_texture*(level: Level, masks: set[CliffMask]): int =
  if TU in masks: return TU.ord
  for mask in masks:
    if mask.cliff(): continue
    return mask.ord
  return IH.ord

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

proc point_uv*(level: Level, i,j,w: int): Vec3f =
  let masks = level.map[i,j].masks
  let color_w = cube_colors[w]
  let vert = cube_verts[ cube_index[w] ]
  let tile = level.point_texture(i, j) + 1
  result = vec3f(vert.x, vert.z, tile.cfloat)

  if color_w in {2,4,3,5}:
    result.z = cfloat CliffMask.high.ord + 2
    if color_w in {2,4}:
      result.x = vert.z
    result.y = vert.y



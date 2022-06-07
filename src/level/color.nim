const default_color = vec4f(0.5, 0.5, 0.5, 1.0)

proc cliff_color(level: Level, mask: CliffMask): Vec4f =
  case mask:
  of AA, JJ: return vec4f(level.color * 0.4, 1.0)
  of LL, VV: return vec4f(level.color * 0.6, 1.0)
  of LV, VJ: return vec4f(level.color * 0.8, 1.0)
  of LA, AJ: return vec4f(level.color * 0.3, 1.0)
  of AH, VH, IL, IJ,
     IH, II, HH:     return vec4f(level.color * 0.9, 0.5)
  else:
    return default_color

proc mask_color*(level: Level, masks: set[CliffMask]): Vec4f =
  for mask in masks:
    case mask:
    of GG:
      return vec4f( 1, 1, 1, 1 )
    of TU, IN, OU:
      return vec4f( level.color.x * 0.5, level.color.y * 0.5, level.color.z * 0.5, 1.0 )
    #of S1: return vec4f( 0.0, 0.0, 0.5, 0.8 )
    #of EM: return vec4f( 0.1, 0.1, 0.1, 1.0 )
    #of EY, EA: return vec4f( 0.4, 9.0, 0.0, 1.0 )
    of P1    : return vec4f( 0.1, 0.2, 0.3, 0.7 )
    of P2    : return vec4f( 0.3, 0.1, 0.2, 0.7 )
    of P3    : return vec4f( 0.2, 0.3, 0.1, 0.7 )
    of P4    : return vec4f( 0.3, 0.2, 0.1, 0.7 )
    of IC    : return vec4f( 0.0, 0.7, 0.7, 0.9 )
    of CU    : return vec4f( 0.8, 0.6, 0.3, 0.9 )
    of SW    : return vec4f( 0.1, 0.6, 0.6, 1.0 )
    of MI    : return vec4f( 0.25, 0.25, 0.25, 1.0 )
    of EP    : return vec4f( 0.5, 0.5, 0.5, 1.0 )
    of RI, RH: return vec4f( 0.2, 0.4, 0.5, 1.0 )
    of BI, BH: return vec4f( 0.4, 0.4, 0.4, 1.0 )
    of SD    : return vec4f( 0.5, 0.3, 0.0, 1.0 )
    of OI    : return vec4f( 0.9, 0.7, 0.5, 1.0 )
    else     : discard
      #return vec4f(((y.float-COLOR_H) * (1.0/COLOR_D)), ((y.float-COLOR_H) * (1.0/COLOR_D)), ((y.float-COLOR_H) * (1.0/COLOR_D)), 0.9)
  return default_color

proc point_cliff_color(level: Level, i,j: int): Vec4f =
  let k = level.width * i + j
  let y = level.data[k]
  if y == EE:
    return vec4f(0,0,0,0)
  elif level.around(IC, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.0, 1.0, 1.0, 1.0)
  elif level.around(CU, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.8, 0.6, 0.3, 0.9)
  else:
    return level.cliff_color(level.mask[k])

proc which_zone(level: Level, i, j: int): Zone =
  result = Zone()
  for zone in level.zones:
    if zone.rect.x <= j and j <= zone.rect.z and zone.rect.y <= i and i <= zone.rect.w:
      return zone

proc point_color(level: Level, i,j: int): Vec4f =
  let k = level.width * i + j
  if k >= level.data.len: return
  let y = level.data[k]
  if y == EE: return

  let masks = level.map[i,j].masks
  if IC in masks: return vec4f( 0.0, 0.7, 0.7, 0.9 )
  if CU in masks: return vec4f( 0.8, 0.6, 0.3, 0.9 )
  if SD in masks: return vec4f( 0.5, 0.3, 0.0, 1.0 )
  if {BI,BH} * masks != {}:
    return vec4f( 0.4, 0.4, 0.4, 1.0 )
  if OI in masks: return vec4f( 0.8, 0.6, 0.4, 0.9 )
  else:
    return level.mask_color(masks)


const ch = 4
proc setup_floor_colors[T](level: Level): seq[cfloat] =
  #const COLOR_H = 44f
  #const COLOR_D = 56f - 44f
  const COLOR_H = 11f
  const COLOR_D = 99f - COLOR_H
  result = newSeq[cfloat](ch * level.width * level.height)
  for z in 0..<level.height:
    for x in 0..<level.width:
      let level_index = level.width * z + x
      let index = ch * level_index
      let c = level.point_color[level_index]
      result[index+0] = c.x
      result[index+1] = c.y
      result[index+2] = c.z
      result[index+3] = c.w


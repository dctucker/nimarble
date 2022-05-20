import glm
import sequtils
import strutils
import std/tables
import std/algorithm

import wrapper
import types
import masks

from models import cube_vert, cube_verts, cube_colors, cube_index
import assets

const EE = 0
const sky* = 200f

proc find_phase_blocks*(level: Level): seq[Zone]

proc flatten[T](input: seq[seq[T]]): seq[T] =
  for row in input:
    for value in row:
      result.add value

proc tsv_floats(line: string): seq[float] =
  result = line.split("\t").map(proc(s:string):float =
    if s.len() > 0: s.parseFloat
    else: 0
  )
  #echo result.len

proc is_numeric(s: string): bool =
  try:
    discard s.parseFloat()
    result = true
  except:
    result = false

proc parse_mask(s: string): CliffMask =
  try:
    result = parseEnum[CliffMask](s)
  except:
    if s.len > 0 and s != "0":
      if not s.is_numeric():
        echo "Unrecognized mask: " & s
    result = CliffMask.XX

proc tsv_masks(line: string): seq[CliffMask] =
  var j = 0
  result = line.split("\t").map(proc(s:string):CliffMask =
    j += 1
    result = parse_mask(s)
  )

proc find_s1(data: seq[float], mask: seq[CliffMask], w,h: int): Vec3i =
  for i in 0..<h:
    for j in 0..<w:
      if mask[i*w+j] == S1:
        return Vec3i(arr: [j.int32, data[i*w+j].int32, i.int32])

proc find_actors(data: seq[float], mask: seq[CliffMask], w,h: int): seq[Actor] =
  for i in 0..<h:
    for j in 0..<w:
      let o = i * w + j
      let mask = mask[o]
      if mask in {EY, EM, EA, EV, EP, EH}:
        result.add Actor(
          origin: vec3i( j.int32, data[o].int32, i.int32 ),
          kind: mask,
        )

proc `~=`(a1, a2: Actor): bool =
  return a1.kind == a2.kind and a1.origin == a2.origin

proc find_actors*(level: var Level) =
  proc has_actor(level: Level, actor: Actor): bool =
    result = false
    for ac in level.actors:
      if ac ~= actor:
        return true
  for actor in find_actors(level.data, level.mask, level.width, level.height):
    if not level.has_actor(actor):
      level.actors.add actor


proc find_fixtures(data: seq[float], mask: seq[CliffMask], w,h: int): seq[Fixture] =
  for i in 0..<h:
    for j in 0..<w:
      let o = i * w + j
      let mask = mask[o]
      if mask in {GR}:
        result.add Fixture(
          origin: vec3i( j.int32, data[o].int32, i.int32 ),
          kind: mask,
        )

proc column_letter(j: int): string =
  result = ""
  var v = j
  var c = 0

  if j < 0:
    return ""
  if j < 26:
    return $char(j + 65)
  if j < 676:
    c = v mod 26
    v = j div 26
    return $char(v + 64) & $char(c + 65)
  else:
    return "MAX"

proc cell_name*(i,j: int): string =
  result = j.column_letter
  if i < 0:
    return
  result &= $(i + 1)

proc validate(level: Level): bool =
  let size = level.width * level.height
  if (size > level.data.len) or (size > level.mask.len):
    echo "Level height:" & $level.height & " width:" & $level.width & " size:" & $size & " do not match data length (" & $level.data.len & ") or mask length (" & $level.mask.len & ")"
    return false
  let w = level.width
  for i in 0..<level.height:
    for j in 0..<w:
      proc unsloped(mask: CliffMask) =
        echo $mask & " without slope at ", cell_name(i, j)
      let data = level.data[i*w+j]
      let mask = level.mask[i*w+j]
      if mask == LL:
        if level.data[i*w+j-1] == data:
          mask.unsloped()
      if mask == AA:
        if level.data[(i-1)*w+j] == data:
          mask.unsloped()
      if mask == VV:
        if level.data[(i+1)*w+j] == data:
          mask.unsloped()
      if mask == JJ:
        if level.data[i*w+j+1] == data:
          mask.unsloped()

proc find_span(level: Level): int =
  for j in 0..<level.width:
    for i in 0..<level.height:
      if level.data[ level.offset(i,j) ] != 0:
        result = max(result, j - i)

proc find_first*(level: Level): (int,int) =
  var ii, jj: int
  for i in 0..<level.height:
    for j in 0..<level.width:
      if level.data[i*level.width + j] != 0:
        ii = i
        break
    if ii > 0: break
  for j in 0..<level.width:
    for i in 0..<level.height:
      if level.data[i*level.width + j] != 0:
        jj = j
    if jj > 0: break
  echo "first = ", ii, ",", jj
  return (ii,jj)

proc find_last*(level: Level): (int,int) =
  var ii, jj: int
  for i in countdown(level.height - 1, 0):
    for j in countdown(level.width - 1, 0):
      if level.data[i*level.width + j] != 0:
        ii = i
    if ii > 0: break
  for j in countdown(level.width - 1, 0):
    for i in countdown(level.height - 1, 0):
      if level.data[i*level.width + j] != 0:
        jj = j
    if jj > 0: break
  echo "last = ", ii, ",", jj
  return (ii,jj)

proc find_zones(level: Level): seq[Zone] =
  let blocks = level.find_phase_blocks()
  for b in blocks:
    result.add b

proc init_map(level: var Level) =
  for i in 0 ..< level.height:
    for j in 0 ..< level.width:
      let o = i*level.width + j
      let mask = level.mask[o]
      if mask != XX:
        level.map[i,j].add mask
      level.map[i,j].height = level.data[o]
  for zone in level.zones:
    # ugh
    for i in zone.rect.y .. zone.rect.w:
      for j in zone.rect.x .. zone.rect.z:
        level.map[i + level.origin.z, j + level.origin.x].masks.incl zone.kind

proc init_level(name, data_src, mask_src: string, color: Vec3f): Level =
  let source_lines = data_src.splitLines().filter(proc(line:string): bool = return line.len > 0)
  let data = source_lines.map(tsv_floats).flatten()
  let mask = mask_src.splitLines.map(tsv_masks).flatten()
  let height = source_lines.len()
  let width = source_lines[0].split("\t").len()
  result = Level(
    name: name,
    height: height,
    width: width,
    data: data,
    mask: mask,
    color: color,
    map: newLevelMap(width, height),
  )
  discard result.validate()
  result.origin   = find_s1(data, mask, width, height)
  result.actors   = find_actors(data, mask, width, height)
  result.fixtures = find_fixtures(data, mask, width, height)
  result.span     = result.find_span()
  result.zones    = result.find_zones()
  result.init_map()
  echo "Level ", result.width, "x", result.height, " span ", result.span

proc `[]=`*(level: Level, i,j: int, mask: CliffMask) =
  let o = level.offset(i,j)
  if o == 0: return
  let cur = level.mask[o]
  level.mask[level.offset(i,j)] = mask
  level.map[i,j].masks.excl cur
  level.map[i,j].masks.excl mask

proc `[]=`*(level: Level, i,j: int, value: float) =
  let o = level.offset(i,j)
  if o == 0: return
  level.map[i,j].height = value
  level.data[o] = value

proc format(value: float): string =
  if value == value.floor:
    return $value.int
  else:
    return $value

proc parseMask*(level: Level, str: string): CliffMask =
  return parse_mask(str)

proc parseFloat*(level: Level, str: string): float =
  try:
    return str.parseFloat()
  except:
    return 0f

proc format*(level: Level, value: float): string =
  return format(value)

proc format*(level: Level, value: CliffMask): string =
  return $value

proc save*(level: Level) =
  if level.name == "":
    level.name = "_"
  let span = level.span
  let data = level.data
  let mask = level.mask
  let h = level.height
  let w = level.width

  let data_fn = level_dir & "/" & level.name & ".tsv"
  let mask_fn = level_dir & "/" & level.name & "mask.tsv"
  let data_out = data_fn.open(fmWrite)
  let mask_out = mask_fn.open(fmWrite)
  for i in 0..<h:
    for j in 0..<w:
      if j >= i and j <= i + span:
        data_out.write data[i * w + j].format
      if j < w - 1:
        data_out.write "\t"
    data_out.write "\l"

    for j in 0..<w:
      let height = data[i * w + j].format
      let value = mask[i * w + j]
      if j >= i and j <= i + span:
        if value == XX:
          mask_out.write height
        else:
          mask_out.write $value
      if j < w - 1:
        mask_out.write "\t"
    mask_out.write "\l"

  data_out.close()
  mask_out.close()
  echo "Saved ", data_fn, " and ", mask_fn

proc write_new_level* =
  const height = 120
  const width = 38 + height
  var level = Level(
    name: "new",
    height: height,
    width: width,
    span: 40,
    data: newSeq[float](width * height),
    mask: newSeq[CliffMask](width * height),
  )
  for i in 2..20:
    for j in i..i+level.span:
      level.data[i * width + j] = 20
  level.save()

let levels = @[
  Level(),
  init_level("0", level_data_src(0), level_mask_src(0), vec3f( 1f  , 0.0f, 1f   )),
  init_level("1", level_data_src(1), level_mask_src(1), vec3f( 1f  , 0.8f, 0f   )),
  init_level("2", level_data_src(2), level_mask_src(2), vec3f( 0f  , 0.4f, 0.8f )),
  init_level("3", level_data_src(3), level_mask_src(3), vec3f( 0.4f, 0.4f, 0.4f )),
  init_level("4", level_data_src(4), level_mask_src(4), vec3f( 1f  , 0.4f, 0.1f )),
  init_level("5", level_data_src(5), level_mask_src(5), vec3f( 1f  , 1.0f, 0.0f )),
  init_level("6", level_data_src(6), level_mask_src(6), vec3f( 1.0f, 0.0f, 0.0f )),
]
let n_levels* = levels.len()

proc xlat_coord*(level: Level, x,z: float): (int,int) =
  return ((z.floor+level.origin.z.float).int, (x.floor+level.origin.x.float).int)

proc has_coord*[T](level: Level, i,j: T): bool =
  result = i >= 0            and
           j >= 0            and
           i <  level.height and
           j <  level.width  and
           j >= i            and
           j - i <= level.span

proc data_at(level: Level, x,z: float): float =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return EE.float
  return level.data[i * level.width + j].float

proc mask_at*(level: Level, x,z: float): CliffMask =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return XX
  return level.mask[i * level.width + j]

proc masks_at*(level: Level, x,z: float): set[CliffMask] =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return {}
  return level.map[i,j].masks

proc around*(level: Level, m: CliffMask, x,z: float): bool =
  if level.masks_at(x,z).has m:
    return true
  for i in -1..1:
    for j in -1..1:
      if level.masks_at(x+i.float,z+j.float).has m:
        return true
  return false

proc find_closest*(level: Level, mask: CliffMask, x, z: float): Vec3f =
  var i, j, di, dj, radius: int
  i = -radius ; j = -radius

  while radius < 50:
    if i <= -radius and j == -radius:
      radius.inc ; i = -radius ; j = -radius ; di =  0 ; dj =  1
    elif i == -radius and j >= radius        : di =  1 ; dj =  0
    elif i >= radius and j == radius         : di =  0 ; dj = -1
    elif i == radius and j <= -radius        : di = -1 ; dj =  0

    #echo "i,j = ", $i, ",", $j

    let xi = x + i.float
    let zj = z + j.float
    if level.masks_at(zj, xi).has mask:
      let y = level.data_at(zj, xi)
      result = vec3f( zj, y, xi )
      #echo "FOUND at ", result
      return

    i += di
    j += dj

iterator by_area(w,h: int): Vec2i =
  proc cmp(v1, v2: Vec3i): int = cmp(v1.y, v2.y)
  var points = newSeqOfCap[Vec3i](w*h)
  for i in 0 ..< h:
    for j in 0 ..< w:
      var area = (i+1)*(j+1)
      points.add vec3i( j.int32, area.int32, i.int32 )
  points.sort(cmp)
  for point in points:
    yield vec2i(point.x, point.z)

proc find_phase_blocks*(level: Level): seq[Zone] =
  var consumed: seq[Vec2i] = @[]
  var criteria: CliffMask
  var first: Vec2i

  proc is_consumed(x,z: int32): bool =
    return vec2i(x, z) in consumed

  proc search_forward(sx,sz: int): Vec2i =
    for point in by_area(5,5):
      result = vec2i( int32 sx + 1 + point.x, int32 sz + 1 + point.y )
      # singular mask detection to identify points within source data
      let mask = level.mask_at( result.x.float, result.y.float )
      if mask == criteria:
        return
    result = vec2i(0,0)

  for x in -level.origin.x ..< level.width - level.origin.x:
    for z in -level.origin.z ..< level.height - level.origin.z:
      if is_consumed(x.int32, z.int32): continue
      criteria = level.mask_at(x.float, z.float)
      if not (criteria in {P1, P2, P3, P4}): continue

      # found start phase block
      first = vec2i(x.int32, z.int32)
      let last = search_forward(x.int, z.int)
      if last.x == 0 and last.y == 0: continue

      # found end phase block
      result.add Zone(
        rect: vec4i( first.x, first.y, last.x, last.y ),
        kind: criteria,
      )
      consumed.add first
      consumed.add last

  for z in result:
    let b = z.rect
    echo $z.kind, " ", cell_name(b.y + level.origin.z, b.x + level.origin.x), "..", cell_name(b.w + level.origin.z, b.z + level.origin.x)

proc cliff_color(level: Level, mask: CliffMask): Vec4f =
  case mask:
  of AA, JJ: return vec4f(level.color * 0.4, 1.0)
  of LL, VV: return vec4f(level.color * 0.6, 1.0)
  of LV, VJ: return vec4f(level.color * 0.8, 1.0)
  of LA, AJ: return vec4f(level.color * 0.3, 1.0)
  of AH, VH, IL, IJ,
     IH, II, HH:     return vec4f(level.color * 0.9, 0.5)
  else:
    return vec4f( 0.6, 0.6, 0.6, 1.0 )

proc mask_color(level: Level, mask: CliffMask): Vec4f =
  case mask:
  of GG:
    return vec4f( 1, 1, 1, 1 )
  of TU, IN, OU:
    return vec4f( level.color.x * 0.5, level.color.y * 0.5, level.color.z * 0.5, 1.0 )
  #of S1: return vec4f( 0.0, 0.0, 0.5, 0.8 )
  #of EM: return vec4f( 0.1, 0.1, 0.1, 1.0 )
  #of EY, EA: return vec4f( 0.4, 9.0, 0.0, 1.0 )
  of P1: return vec4f( 0.1, 0.2, 0.3, 0.7 )
  of P2: return vec4f( 0.3, 0.1, 0.2, 0.7 )
  of P3: return vec4f( 0.2, 0.3, 0.1, 0.7 )
  of P4: return vec4f( 0.3, 0.2, 0.1, 0.7 )
  of SW:
    return vec4f( 0.1, 0.6, 0.6, 1.0 )
  of RI, RH:
    return vec4f( 0.2, 0.7, 0.7, 0.9 )
  else:
    return vec4f( 0.6, 0.6, 0.6, 1.0 )
    #return vec4f(((y.float-COLOR_H) * (1.0/COLOR_D)), ((y.float-COLOR_H) * (1.0/COLOR_D)), ((y.float-COLOR_H) * (1.0/COLOR_D)), 0.9)

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

  let zone = level.which_zone(i - level.origin.z, j - level.origin.x)
  if zone.kind != XX:
    #echo "zone ", $zone.kind, $zone.rect
    return level.mask_color(zone.kind)


  if   level.around(IC, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.0, 1.0, 1.0, 1.0)
  elif level.around(CU, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.8, 0.6, 0.3, 0.9)
  elif level.around(OI, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.9, 0.7, 0.5, 1.0 )
  elif level.around(SD, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.5, 0.3, 0.0, 1.0 )
  elif level.around(BI, j.float - level.origin.x.float, i.float - level.origin.z.float) or
       level.around(BH, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.4, 0.4, 0.4, 1.0 )
  else:
    return level.mask_color(level.mask[k])

proc add_normal(normals: var seq[cfloat], n: Vec3f) =
  let nn = n.normalize()
  normals.add nn.x
  normals.add nn.y
  normals.add nn.z

proc add_color(colors: var seq[cfloat], c: Vec4f) =
  colors.add c.x
  colors.add c.y
  colors.add c.z
  colors.add c.w

proc cube_point*(level: Level, i,j, w: int): CubePoint =
  let vert = cube_verts[ cube_index[w] ]

  let m0 = level.map[i+0, j+0].cliffs
  let m1 = level.map[i+0, j+1].cliffs
  let m2 = level.map[i+1, j+0].cliffs
  let m3 = level.map[i+1, j+1].cliffs

  var y0 = level.map[i+0, j+0].height
  var y1 = level.map[i+0, j+1].height
  var y2 = level.map[i+1, j+0].height
  var y3 = level.map[i+1, j+1].height

  if level.map[i,j].masks.has level.phase:
    y0 = 0
    y1 = 0
    y2 = 0
    y3 = 0

  const margin = 0.98
  let x = (j - level.origin.x).float + vert.x.float * margin
  let z = (i - level.origin.z).float + vert.z.float * margin
  var y = level.data[level.offset(i+vert.z, j+vert.x)]
  var c = level.point_color(i+vert.z, j+vert.x)
  var m = level.mask[level.offset(i+vert.z, j+vert.x)]

  let surface_normals = @[
    vec3f(-1, -1, -1) * -y0,
    vec3f(+1, -1, -1) * -y1,
    vec3f(-1, -1, +1) * -y2,
    vec3f(+1, -1, +1) * -y3,
  ]
  var surface_normal: Vec3f # = surface_normals[0] + surface_normals[1] + surface_normals[2] + surface_normals[3]
  var normal: Vec3f         # = surface_normals[0] + surface_normals[1] + surface_normals[2] + surface_normals[3]

  let na = vec3f(-1, y0 - y0, -1).normalize()
  let nc = vec3f(+1, y1 - y0, -1).normalize()
  let nb = vec3f(-1, y2 - y0, +1).normalize()
  let nd = vec3f(+1, y3 - y0, +1).normalize()
  surface_normal = normalize(
    (nb - na).cross(nc - nb) +
    (nc - nb).cross(nd - nc)
  )

  var base: float = -1

  if FL in {m0, m1, m2, m3}: base = y0 - 1.5

  if vert.y == 1:

    if m.has JJ:
      y0 = y1
      y2 = y3

    if m.has VV:
      y0 = y2
      y1 = y3

    if m1.has LL:
      y1 = y0

    if m3.has LL:
      y1 = y0
      y3 = y2

    if m2.has AA:
      y2 = y0
      y3 = y1

    if m3.has AA:
      y3 = y1

    if m1.has(VV) and m2.has JJ:
      y0 = y3

    if y0 == 0 or y1 == 0 or y2 == 0 or y3 == 0:
      y0 = base ; y1 = base ; y2 = base ; y3 = base

    const too_high = 5
    if   (y0 - y1) >= too_high: y0 = y1
    elif (y1 - y0) >= too_high: y1 = y0
    if   (y0 - y2) >= too_high: y0 = y2
    elif (y2 - y0) >= too_high: y2 = y0
    if   (y2 - y3) >= too_high: y2 = y3
    elif (y3 - y2) >= too_high: y3 = y2
    if   (y1 - y3) >= too_high: y1 = y3
    if   (y3 - y1) >= too_high: y3 = y1
    if   vert.z == 0 and vert.x == 0: y = y0
    elif vert.z == 0 and vert.x == 1: y = y1
    elif vert.z == 1 and vert.x == 0: y = y2
    elif vert.z == 1 and vert.x == 1: y = y3
  else:
    y = base

  if y == 0:
    y = base

  let color_w = cube_colors[w]
  c = case color_w
  of 0   : vec4f(0,0,0,0)
  of 2, 4: level.cliff_color(JJ)
  of 3, 5: level.cliff_color(VV)
  else   : c

  #if color_w == 4: c = vec4f(1,0,1,1)

  normal = case color_w
  of 3: vec3f(  0,  0, -1 )
  of 4: vec3f( +1,  0,  0 )
  of 5: vec3f(  0,  0, +1 )
  of 2: vec3f( -1,  0,  0 )
  of 1: surface_normal
  else: vec3f(  0,  0,  0 )

  return CubePoint(
    pos    : vec3f(x, y, z),
    color  : c,
    normal : normal,
  )

proc update_vbos*(level: Level) =
  level.floor_plane.vert_vbo.update  level.floor_verts
  level.floor_plane.color_vbo.update level.floor_colors
  level.floor_plane.norm_vbo.update  level.floor_normals

const floor_span = 48
proc calculate_vbos*(level: Level, i,j: int) =
  let color_span  = 4 * cube_index.len
  let normal_span = 3 * cube_index.len
  let vert_span   = 3 * cube_index.len

  if not level.has_coord(i,j): return

  let o = (i-1) * floor_span + (j-7)
  if o < 0: return
  for n in cube_index.low .. cube_index.high:
    let p = level.cube_point(i, j, n)
    if p.empty: continue
    let vert_offset = o *   vert_span + 3*n + 1
    if vert_offset >= level.floor_verts.len:
      break
    level.floor_verts[   vert_offset               ] = p.pos.y

    let color_offset = o *  color_span + 4*n
    if 0 < color_offset and color_offset < level.floor_colors.len:
      level.floor_colors[  color_offset + 0 ] = p.color.x
      level.floor_colors[  color_offset + 1 ] = p.color.y
      level.floor_colors[  color_offset + 2 ] = p.color.z
      level.floor_colors[  color_offset + 3 ] = p.color.w

    let normal_offset = o * normal_span + 3*n
    if 0 < normal_offset and normal_offset < level.floor_normals.len:
      level.floor_normals[ normal_offset + 0 ] = p.normal.x
      level.floor_normals[ normal_offset + 1 ] = p.normal.y
      level.floor_normals[ normal_offset + 2 ] = p.normal.z

proc setup_floor(level: Level) =
  let dim = level.height * level.width
  var cx: Vec4f
  var normals = newSeqOfCap[cfloat]( dim )
  var lookup  = newTable[(cfloat,cfloat,cfloat), Ind]()
  var verts   = newSeqOfCap[cfloat]( 3 * dim )
  var index   = newSeqOfCap[Ind]( cube_index.len * dim )
  var colors  = newSeqOfCap[cfloat]( 4 * cube_verts.len * dim )
  var n = 0.Ind
  var x,z: float
  var y, y0, y1, y2, y3: float
  var m, m0, m1, m2, m3: CliffMask
  var c, c0, c1, c2, c3: Vec4f
  var v00, v01, v02, v03: Vec3f
  var v10, v11, v12, v13: Vec3f
  var v20, v21, v22, v23: Vec3f
  var v30, v31, v32, v33: Vec3f
  var surface_normal: Vec3f
  var normal: Vec3f

  proc add_index =
    index.add n
    inc n
  proc add_index(nn: Ind) =
    index.add nn

  proc add_point(x,y,z: cfloat, c: Vec4f) =
    if lookup.hasKey((x,y,z)):
      let nn = lookup[(x,y,z)]
      index.add nn
      #echo "n: ", nn
    else:
      verts.add x
      verts.add y
      verts.add z

      # TODO: lookup is current unused, and complicates the update calculations
      #lookup[(x,y,z)] = n
      #echo "n: ", $n, ", x: ", $x, ", y: ", $y, ", z: ", $z
      add_index()
      colors.add_color c
      #normals.add_normal normal

  for i in  1..<level.height - 1:
    for j in 1..<level.width - 1:
      if j + 4 < i or j + 4 > i + floor_span: continue

      for w in 0 .. cube_index.high:
        let point = level.cube_point(i, j, w)
        normals.add_normal point.normal

        const margin = 0.98
        add_point point.pos.x, point.pos.y, point.pos.z, point.color

  level.floor_lookup = lookup
  level.floor_colors = colors
  level.floor_verts = verts
  level.floor_index = index
  level.floor_normals = normals
  #echo "Index length: ", index.len


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

proc wave_height*(level: Level, x,z: float): float =
  let phase = 15f * -x + level.clock.float
  const max_height = 3f
  result = max_height * sin(phase.radians)
  result = clamp( result, 0, max_height )

proc floor_height*(level: Level, x,z: float): float =
  result = level.data_at(x,z)
  if level.masks_at(x,z).has SW:
    result += level.wave_height(x,z)
    #let (i,j) = level.xlat_coord(x,z)
    #if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return
    #level.floor_verts[4 * (i * level.width + j)] = result

proc surface_normal*(level: Level, x,z: float): Vec3f =
  let p0 = level.floor_height(x,z)
  let p1 = level.floor_height(x+1,z)
  let p2 = level.floor_height(x,z+1)
  let u = vec3f(1, p1-p0, 0)
  let v = vec3f(0, p2-p0, 1)
  result = v.cross(u).normalize()

proc toString(x: float): string =
  x.formatFloat(ffDecimal,3)

proc slope*(level: Level, x,z: float): Vec3f =
  # this should be refactored to use masks_at
  let m0 = level.mask_at(x+0,z+0)
  let m1 = level.mask_at(x+1,z+0)
  let m2 = level.mask_at(x+0,z+1)
  let p0 = level.floor_height(x+0,z+0)
  let p1 = level.floor_height(x+1,z+0)
  let p2 = level.floor_height(x+0,z+1)
  var dx = p0 - p1
  var dz = p0 - p2

  const pushback = 30
  if (m0 == XX) and (m2.has AA):
    dz = -pushback

  if (m2 == XX) and (m0.has VV):
    dz = +pushback

  if (m0 == XX) and (m1.has LL):
    dx = -pushback

  if (m1 == XX) and (m0.has JJ):
    dx = +pushback

  result = vec3f( dx, 0f, dz )
  if result.length > pushback:
    result = result.normalize() * pushback

proc point_height*(level: Level, x,z: float): float =
  let h1 = level.floor_height( x+0, z+0 )
  let h2 = level.floor_height( x+1, z+0 )
  let h3 = level.floor_height( x+0, z+1 )
  let h4 = level.floor_height( x+1, z+1 )
  let ux = x - x.floor
  let uz = z - z.floor
  result  = h1 * (1-ux) * (1-uz)
  result += h2 *    ux  * (1-uz)
  result += h3 * (1-ux) *    uz
  result += h4 *    ux  *    uz
  #stdout.write ", floor = ", result.formatFloat(ffDecimal, 3)

proc average_height*(level: Level, x,z: float): float =
  const max_cells = 9
  const max_iters = 81
  var n = 1
  var sum = level.floor_height(x,z)
  proc accum(v: float) =
    if v != EE and v > 0:
      sum += v
      inc n
  var i = 0
  while n < max_cells and i < max_iters:
    inc i
    let ii = i.float
    accum level.floor_height(x+ii, z)
    accum level.floor_height(x-ii, z)
    accum level.floor_height(x  , z+ii)
    accum level.floor_height(x  , z-ii)
    for j in 1..i:
      let jj = j.float
      accum level.floor_height(x+ii, z+jj)
      accum level.floor_height(x-ii, z-jj)
      accum level.floor_height(x-ii, z+jj)
      accum level.floor_height(x+ii, z-jj)
  return sum / n.float

proc load_level*(n: int) =
  if 0 < n and n < levels.len:
    if levels[n].floor_index.len == 0:
      setup_floor levels[n]

proc get_level*(n: var int32): Level =
  while n > levels.high:
    dec n
  while n < 1:
    inc n
  return levels[n]


proc apply_phase(level: Level, i,j: int) =
  level.calculate_vbos(i,j)

proc tick*(level: var Level, t: float) =
  level.clock = t
  let phase = CliffMask(P1.ord + (level.clock.floor.int mod 4))

  if level.phase != phase:
    let previous = level.phase
    level.phase = phase

    for zone in level.zones:
      if zone.kind notin {previous, level.phase}: continue
      for z in zone.rect.y .. zone.rect.w:
        for x in zone.rect.x .. zone.rect.z:
          let (i,j) = level.xlat_coord(x.float, z.float)
          level.apply_phase(i,j)
  level.update_vbos()


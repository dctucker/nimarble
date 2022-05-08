import glm
import sequtils
import strutils
import std/tables

import types

from models import cube_vert, cube_verts, cube_colors, cube_index

const EE = 0
const sky* = 200f

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

proc find_p1(data: seq[float], mask: seq[CliffMask], w,h: int): Vec3i =
  for i in 0..<h:
    for j in 0..<w:
      if mask[i*w+j] == P1:
        return Vec3i(arr: [j.int32, data[i*w+j].int32, i.int32])

proc find_actors(data: seq[float], mask: seq[CliffMask], w,h: int): seq[Actor] =
  for i in 0..<h:
    for j in 0..<w:
      let o = i * w + j
      #if o >= mask.len: return
      let mask = mask[o]
      if mask in {EY, EM, EA, EV, EP, EH}:
        result.add Actor(
          origin: vec3i( j.int32, data[o].int32, i.int32 ),
          kind: mask,
        )

proc validate(level: Level): bool =
  let size = level.width * level.height
  if (size > level.data.len) or (size > level.mask.len):
    echo "Level height:" & $level.height & " width:" & $level.width & " size:" & $size & " do not match data length (" & $level.data.len & ") or mask length (" & $level.mask.len & ")"
    return false
  let w = level.width
  for i in 0..<level.height:
    for j in 0..<w:
      proc unsloped(mask: CliffMask) =
        echo $mask & " without slope at ", i, ",", j
      let data = level.data[i*w+j]
      let mask = level.mask[i*w+j]
      if mask.has LL:
        if level.data[i*w+j-1] == data:
          mask.unsloped()
      if mask.has AA:
        if level.data[(i-1)*w+j] == data:
          mask.unsloped()
      if mask.has VV:
        if level.data[(i+1)*w+j] == data:
          mask.unsloped()
      if mask.has JJ:
        if level.data[i*w+j+1] == data:
          mask.unsloped()

proc find_span(level: Level): int =
  for i in 0..<level.height:
    for j in 0..<level.width:
      if level.data[ level.offset(i,j) ] != 0:
        result = max(result, j - i)

proc init_level(name, data_src, mask_src: string, color: Vec3f): Level =
  var i,j: int

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
  )
  discard result.validate()
  result.origin = data.find_p1(mask, width, height)
  result.actors = data.find_actors(mask, width, height)
  result.span   = result.find_span()

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

  let data_fn = "levels/" & level.name & ".tsv"
  let mask_fn = "levels/" & level.name & "mask.tsv"
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

const level_0_src      = staticRead("../levels/0.tsv")
const level_0_mask_src = staticRead("../levels/0mask.tsv")

const level_1_src      = staticRead("../levels/1.tsv")
const level_1_mask_src = staticRead("../levels/1mask.tsv")

const level_2_src      = staticRead("../levels/2.tsv")
const level_2_mask_src = staticRead("../levels/2mask.tsv")

const level_3_src      = staticRead("../levels/3.tsv")
const level_3_mask_src = staticRead("../levels/3mask.tsv")

const level_4_src      = staticRead("../levels/4.tsv")
const level_4_mask_src = staticRead("../levels/4mask.tsv")

let levels = @[
  Level(),
  init_level("0", level_0_src, level_0_mask_src, vec3f(1f, 0.0f, 1f)),
  init_level("1", level_1_src, level_1_mask_src, vec3f(1f, 0.8f, 0f)),
  init_level("2", level_2_src, level_2_mask_src, vec3f(0f, 0.4f, 0.8f)),
  init_level("3", level_3_src, level_3_mask_src, vec3f(0.4f, 0.4f, 0.4f)),
  init_level("4", level_4_src, level_4_mask_src, vec3f(1f, 0.4f, 0.1f)),
]
let n_levels* = levels.len()

proc xlat_coord(level: Level, x,z: float): (int,int) =
  return ((z.floor+level.origin.z.float).int, (x.floor+level.origin.x.float).int)

proc mask_at*(level: Level, x,z: float): CliffMask =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return XX
  return level.mask[i * level.width + j]

proc around*(level: Level, m: CliffMask, x,z: float): bool =
  if level.mask_at(x,z) == m:
    return true
  for i in -1..1:
    for j in -1..1:
      if level.mask_at(x+i.float,z+j.float) == m:
        return true
  return false

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
  of P1:
    return vec4f( 0.0, 0.0, 0.5, 0.8 )
  of EM:
    return vec4f( 0.1, 0.1, 0.1, 1.0 )
  of EY, EA:
    return vec4f( 0.4, 9.0, 0.0, 1.0 )
  of SW:
    return vec4f( 0.1, 0.6, 0.6, 1.0 )
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

proc point_color(level: Level, i,j: int): Vec4f =
  let k = level.width * i + j
  let y = level.data[k]
  if y == EE:
    return vec4f(0,0,0,0)
  elif level.around(IC, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.0, 1.0, 1.0, 1.0)
  elif level.around(CU, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.8, 0.6, 0.3, 0.9)
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

proc cube_point(level: Level, i,j, w: int): CubePoint =
  let vert = cube_verts[ cube_index[w] ]

  let m0 = level.mask[level.offset(i+0,j+0)]
  let m1 = level.mask[level.offset(i+0,j+1)]
  let m2 = level.mask[level.offset(i+1,j+0)]
  let m3 = level.mask[level.offset(i+1,j+1)]

  let y0 = level.data[level.offset(i+0,j+0)]
  let y1 = level.data[level.offset(i+0,j+1)]
  let y2 = level.data[level.offset(i+1,j+0)]
  let y3 = level.data[level.offset(i+1,j+1)]

  let color_w = cube_colors[w]
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

  const abyss = -1

  if vert.y == 1:
    if   vert.z == 0 and vert.x == 0:
      if m.has AA: y = y0
      if m.has LL: y = y0
      if m.has VV: y = y2
      if m.has JJ: y = y1
      if m1.has(VV) and m2.has(JJ): y = y3 # why does this work?
      #normal = surface_normals[0]
    elif vert.z == 0 and vert.x == 1:
      if m.has AA: y = y1
      if m.has LL: y = y0
      if m.has VV: y = y3
      if m.has JJ: y = y1
      #normal = surface_normals[1]
    elif vert.z == 1 and vert.x == 0:
      if m.has AA: y = y0
      if m.has VV: y = y2
      if m.has JJ: y = y3
      if m.has LL: y = y2
      #normal = surface_normals[2]
    elif vert.z == 1 and vert.x == 1:
      if m.has AA: y = y1
      if m.has LL: y = y2
      if m.has JJ: y = y3
      if m.has VV: y = y3
      #normal = surface_normals[3]
  else:
    y = abyss
    #c = vec4f(0,0,0,1.0)

  if y == 0:
    y = abyss

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

  return CubePoint( height: y, color: c, normal: normal )

proc update_vbos*(level: Level) =
  level.floor_plane.vert_vbo.update  level.floor_verts
  level.floor_plane.color_vbo.update level.floor_colors
  level.floor_plane.norm_vbo.update  level.floor_normals

proc calculate_vbos*(level: Level, i,j: int) =
  let color_span  = 4 * 33
  let normal_span = 3 * 33
  let vert_span   = 3 * 33

  if i < 0 or j < 0 or j < i - 4 or j > i + 44: return

  let o = (i-1) * 48 + (j-7)
  for w in 22 .. 26:
    let p = level.cube_point(i, j, w)
    for n in cube_index.low .. cube_index.high:
      if cube_index[n] == cube_index[w]:
        level.floor_verts[   o *   vert_span + 3*n + 1 ] = p.height

    level.floor_colors[  o *  color_span + 4*w + 0 ] = p.color.x
    level.floor_colors[  o *  color_span + 4*w + 1 ] = p.color.y
    level.floor_colors[  o *  color_span + 4*w + 2 ] = p.color.z
    level.floor_colors[  o *  color_span + 4*w + 3 ] = p.color.w
    level.floor_normals[ o * normal_span + 3*w + 0 ] = p.normal.x
    level.floor_normals[ o * normal_span + 3*w + 1 ] = p.normal.y
    level.floor_normals[ o * normal_span + 3*w + 2 ] = p.normal.z

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

  for i in  1..<level.height-1:
    for j in 1..<level.width-1:

      #level.update_vbos(i, j)

      x = (j - level.origin.x).float
      z = (i - level.origin.z).float

      if j < i - 4 or j > i + 44: continue

      cx = level.point_color(i+0,j+0)
      c0 = level.point_cliff_color(i+0,j+0)
      c1 = level.point_cliff_color(i+0,j+1)
      c2 = level.point_cliff_color(i+1,j+0)
      c3 = level.point_cliff_color(i+1,j+1)

      y0 = level.data[level.offset(i+0,j+0)]
      y1 = level.data[level.offset(i+0,j+1)]
      y2 = level.data[level.offset(i+1,j+0)]
      y3 = level.data[level.offset(i+1,j+1)]

      #let normal = normalize(
      let surface_normals = @[
        vec3f(-1, -1, -1) * -y0,
        vec3f(+1, -1, -1) * -y1,
        vec3f(-1, -1, +1) * -y2,
        vec3f(+1, -1, +1) * -y3,
      ]

      let na = vec3f(-1, y0 - y0, -1).normalize()
      let nc = vec3f(+1, y1 - y0, -1).normalize()
      let nb = vec3f(-1, y2 - y0, +1).normalize()
      let nd = vec3f(+1, y3 - y0, +1).normalize()
      surface_normal = normalize(
        (nb - na).cross(nc - nb) +
        (nc - nb).cross(nd - nc)
      )

      var w = 0
      for vert in cube_vert():
        m0 = level.mask[level.offset(i+0,j+0)]
        m1 = level.mask[level.offset(i+0,j+1)]
        m2 = level.mask[level.offset(i+1,j+0)]
        m3 = level.mask[level.offset(i+1,j+1)]

        let color_w = cube_colors[w]
        y = level.data[level.offset(i+vert.z, j+vert.x)]
        c = level.point_color(i+vert.z, j+vert.x)
        m = level.mask[level.offset(i+vert.z, j+vert.x)]

        const abyss = -1

        if vert.y == 1:
          if   vert.z == 0 and vert.x == 0:
            if m.has AA: y = y0
            if m.has LL: y = y0
            if m.has VV: y = y2
            if m.has JJ: y = y1
            if m1.has(VV) and m2.has(JJ): y = y3 # why does this work?
            #normal = surface_normals[0]
          elif vert.z == 0 and vert.x == 1:
            if m.has AA: y = y1
            if m.has LL: y = y0
            if m.has VV: y = y3
            if m.has JJ: y = y1
            #normal = surface_normals[1]
          elif vert.z == 1 and vert.x == 0:
            if m.has AA: y = y0
            if m.has VV: y = y2
            if m.has JJ: y = y3
            if m.has LL: y = y2
            #normal = surface_normals[2]
          elif vert.z == 1 and vert.x == 1:
            if m.has AA: y = y1
            if m.has LL: y = y2
            if m.has JJ: y = y3
            if m.has VV: y = y3
            #normal = surface_normals[3]
        else:
          y = abyss
          #c = vec4f(0,0,0,1.0)

        if y == 0:
          y = abyss - 1

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

        normals.add_normal normal

        const margin = 0.98
        add_point x + vert.x.float * margin, y, z + vert.z.float * margin, c
        #let n = vert.x * 4 + vert.y * 2 + vert.z

        inc w

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

proc data_at(level: Level, x,z: float): float =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return EE.float
  return level.data[i * level.width + j].float

proc floor_height*(level: Level, x,z: float): float =
  result = level.data_at(x,z)
  if level.mask_at(x,z) == SW:
    let phase = 15f * -x + level.clock.float
    result += 3.0f * (1f + sin(phase.radians))
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

proc get_level*(game: Game): Level =
  while game.level > levels.high:
    dec game.level
  while game.level < 1:
    inc game.level
  return levels[game.level]


import glm
import sequtils
import strutils
import std/tables

import types

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
      let mask = mask[i * w + j]
      if mask in {EY, EM, EA}:
        result.add Actor(
          origin: vec3i(
            j.int32,
            data[i*w+j].int32,
            i.int32,
          ),
          kind: mask,
        )

proc validate(level: Level) =
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

proc init_level(data_src, mask_src: string, color: Vec3f): Level =
  var i,j: int

  let source_lines = data_src.splitLines()
  let data = source_lines.map(tsv_floats).flatten()
  let mask = mask_src.splitLines.map(tsv_masks).flatten()
  let height = source_lines.len()
  let width = source_lines[0].split("\t").len()
  result = Level(
    height: height,
    width: width,
    data: data,
    mask: mask,
    color: color,
  )
  result.origin = data.find_p1(mask, width, height)
  result.actors = data.find_actors(mask, width, height)

const level_0_src      = staticRead("../levels/0.tsv")
const level_0_mask_src = staticRead("../levels/0mask.tsv")

const level_1_src      = staticRead("../levels/1.tsv")
const level_1_mask_src = staticRead("../levels/1mask.tsv")

const level_2_src      = staticRead("../levels/2.tsv")
const level_2_mask_src = staticRead("../levels/2mask.tsv")

const level_3_src      = staticRead("../levels/3.tsv")
const level_3_mask_src = staticRead("../levels/3mask.tsv")

let levels = @[
  Level(),
  init_level(level_0_src, level_0_mask_src, vec3f(1f, 0.0f, 1f)),
  init_level(level_1_src, level_1_mask_src, vec3f(1f, 0.8f, 0f)),
  init_level(level_2_src, level_2_mask_src, vec3f(0f, 0.4f, 0.8f)),
  init_level(level_3_src, level_3_mask_src, vec3f(0.4f, 0.4f, 0.4f)),
]
let n_levels* = levels.len()

for l in 1..levels.high:
  echo "Level ", $l
  levels[l].validate()

var current_level*: int32

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

proc point_color(level: Level, i,j: int): Vec4f =
  let k = level.width * i + j
  let y = level.data[k]
  if y == EE:
    return vec4f(0,0,0,0)
  elif level.around(IC, j.float - level.origin.x.float, i.float - level.origin.z.float):
    return vec4f( 0.0, 1.0, 1.0, 1.0)
  else:
    case level.mask[k]
    of GG:
      return vec4f( 0.8, 0.8, 0.8, 1.0)
    of TU, IN, OU:
      return vec4f( level.color.x * 0.5, level.color.y * 0.5, level.color.z * 0.5, 1.0)
    of AA, JJ: return vec4f(level.color * 0.2, 0.5)
    of LL, VV: return vec4f(level.color * 0.5, 0.5)
    of LV, VJ: return vec4f(level.color * 0.7, 1.0)
    of LA, AJ: return vec4f(level.color * 0.2, 1.0)
    of AH, VH, IL, IJ,
       IH, II, HH:     return vec4f(level.color * 0.9, 0.5)
    of P1:
      return vec4f( 0.0, 0.0, 0.5, 0.8)
    of EM:
      return vec4f( 0.1, 0.1, 0.1, 1.0)
    of EY, EA:
      return vec4f( 0.4, 9.0, 0.0, 1.0)
    of SW:
      return vec4f( 0.1, 0.6, 0.6, 1.0)
    else:
      return vec4f(0.7)
      #return vec4f(((y.float-COLOR_H) * (1.0/COLOR_D)), ((y.float-COLOR_H) * (1.0/COLOR_D)), ((y.float-COLOR_H) * (1.0/COLOR_D)), 0.9)

proc setup_floor(level: Level) =
  const nv = 8
  var lookup = newTable[(cfloat,cfloat,cfloat), Ind]()
  var verts = newSeqOfCap[cfloat]( level.width * level.height)
  var index = newSeqOfCap[Ind]( level.width * level.height * nv)
  var colors = newSeqOfCap[cfloat](level.width * level.height * nv * 4)
  var n = 0.Ind
  var x,y,z: float
  var y0, y1, y2, y3: float

  proc offset[T:Ordinal](level: Level, i,j: T): T =
    if j >= level.width or j < 0: return 0
    if i >= level.height or i < 0: return 0
    result = level.width * i + j

  proc add_color(i,j:int) =
    let c = level.point_color(i,j)
    colors.add c.x
    colors.add c.y
    colors.add c.z
    colors.add 0.9f

  proc add_index =
    index.add n
    inc n
  proc add_index(nn: Ind) =
    index.add nn

  proc add_point(x,y,z: cfloat, i,j:int) =
    if lookup.hasKey((x,y,z)):
      index.add lookup[(x,y,z)]
    else:
      verts.add x
      verts.add y
      verts.add z
      add_index()
      add_color(i,j)

  for i in  1..<level.height-1:
    for j in 1..<level.width-1:
      x = (j - level.origin.x).float
      z = (i - level.origin.z).float

      if j < i - 4 or j > i + 44: continue

      y0 = level.data[level.offset(i+0,j+0)]
      y1 = level.data[level.offset(i+0,j+1)]
      y2 = level.data[level.offset(i+1,j+0)]
      y3 = level.data[level.offset(i+1,j+1)]

      add_point x+0, y0, z+0, i+0, j+0
      add_point x+1, y1, z+0, i+0, j+1

      if level.mask[level.offset(i+1,j+0)].has AA:
        add_point x+0, y2, z+0, i+0, j+0
        add_point x+1, y3, z+0, i+0, j+1


      if level.mask[level.offset(i+0,j+0)].has VV:
        add_point x+0, y2, z+0, i+0, j+0
        add_point x+1, y3, z+0, i+0, j+1
        add_point x+0, y2, z+0, i+1, j+0
        add_point x+1, y3, z+0, i+1, j+1


      add_point x+0, y2, z+1, i+1, j+0
      add_point x+1, y3, z+1, i+1, j+1

      if level.mask[level.offset(i+0,j+1)].has VV:
        add_point x+1, y3, z+0, i+0, j+1
        add_point x+1, y3, z+0, i+0, j+1
        add_point x+1, y1, z+0, i+0, j+1



      #if level.mask[level.offset(i,j)].has JJ:
      #  add_point(x,y,z,i,j)

      #if level.mask[level.offset(i,j)].has AA:
      #  y = level.data[level.offset(i-1,j)]
      #  add_point(x,y,z,i,j)
      #if level.mask[level.offset(i,j)].has LL:
      #  y = level.data[level.offset(i,j-1)]
      #  add_point(x,y,z,i,j)
      #if level.mask[level.offset(i,j)].has JJ:
      #  y = level.data[level.offset(i,j+1)]
      #  add_point(x,y,z,i,j)


  level.floor_colors = colors
  level.floor_verts = verts
  level.floor_index = index
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

  const pushback = 55
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


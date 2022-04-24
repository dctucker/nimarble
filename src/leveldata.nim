import glm
import sequtils
import strutils

const EE = 0
const sky* = 120f

type
  CliffMask* = enum
    xx = 0,     # regulard slope
    LL = 1,     # L is left
    JJ = 2,     # J is right
    HH,         # H is left and right
    AA = 4,     # A is up
    LA, AJ, AH,
    VV = 8,     # V is down
    LV, VJ, VH,
    II, IL, IJ, # I is top and bottom
    IH,         # oops! all cliffs
    GG,         # goal
    TU,         # tube
    IC,         # icy
    P1,         # player 1 start position

  Level = ref object
    width, height: int
    origin: Vec3i
    data: seq[float]
    mask: seq[CliffMask]
    color: Vec3f

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
    result = xx

proc tsv_masks(line: string): seq[CliffMask] =
  var j = 0
  result = line.split("\t").map(proc(s:string):CliffMask =
    j += 1
    result = parse_mask(s)
  )

proc find_p1(data: seq[float], mask: seq[CliffMask], w,h: int): Vec3i =
  for i in 0..h:
    for j in 0..w:
      if mask[i*w+j] == P1:
        return Vec3i(arr: [j.int32, data[i*w+j].int32, i.int32])

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
    origin: data.find_p1(mask, width, height),
    color: color,
  )

const level_1_src = staticRead("../levels/1.tsv")
const level_1_mask_src = staticRead("../levels/1mask.tsv")

const level_2_src = staticRead("../levels/2.tsv")
const level_2_mask_src = staticRead("../levels/2mask.tsv")

let levels = @[
  Level(),
  init_level(level_1_src, level_1_mask_src, vec3f(1f, 0.8f, 0f)),
  init_level(level_2_src, level_2_mask_src, vec3f(0f, 0.4f, 0.8f)),
]
var level_ref: Level

var w,h: int
var ox*, oy*, oz*: float

proc get_value[T](level: seq[T], x,z: int): T =
  let index = w * z + x
  if index in level_ref.low..level_ref.high:
    return level[index]
  return EE

proc setup_floor_verts[T](level: seq[T], level_mask: seq[CliffMask]): seq[cfloat] =
  const q = 0.5
  const dim = 3
  const nv = 8
  var verts = newSeqOfCap[cfloat](dim * w * w)
  for z in -oz..<h-oz:
    for x in -ox..<w-ox:
      let offset = w * z + x
      let y = level_data[offset]

      verts.add cfloat x - q
      verts.add cfloat y
      verts.add cfloat z - q

      verts.add cfloat x - q
      verts.add cfloat y
      verts.add cfloat z + q

      verts.add cfloat x + q
      verts.add cfloat y
      verts.add cfloat z - q

      verts.add cfloat x + q
      verts.add cfloat y
      verts.add cfloat z + q


      let left = ( get_value(x - 1, z).cfloat + y.cfloat ) / 2.cfloat
      if level_mask[offset] and LL: # left
        discard
      else:
        discard
      verts.add cfloat x - q
      verts.add cfloat left
      verts.add cfloat z - q

      if level_mask[offset] and JJ: # right
        discard
      else:
        discard
      if level_mask[offset] and AA: # up
        discard
      else:
        discard
      if level_mask[offset] and VV: # down
        discard
      else:
        discard

  result = verts

proc setup_floor_points[T](level_data: seq[T], level_mask: seq[CliffMask]): seq[cfloat] =
  result = newSeq[cfloat](3 * w * h)
  for z in 0..<h:
    for x in 0..<w:
      let index = 3 * (w * z + x)
      let y = level_data[w * z + x]
      result[index+0] = (x.cfloat-ox).cfloat
      result[index+1] =  y.cfloat
      result[index+2] = (z.cfloat-oz).cfloat

const ch = 4
proc setup_floor_colors[T](level_data: seq[T], level_mask: seq[CliffMask], level_color: Vec3f): seq[cfloat] =
  #const COLOR_H = 44f
  #const COLOR_D = 56f - 44f
  const COLOR_H = 11f
  const COLOR_D = 99f - COLOR_H
  result = newSeq[cfloat](ch * w * h)
  for z in 0..<h:
    for x in 0..<w:
      let level_index = w * z + x
      let index = ch * level_index
      let y = level_data[level_index]
      if y == EE:
        result[index+0] = 0.0
        result[index+1] = 0.0
        result[index+2] = 0.0
        result[index+3] = 0.0
      else:
        case level_mask[level_index]
        of IC:
          result[index+0] = 0.0
          result[index+1] = 1.0
          result[index+2] = 1.0
          result[index+3] = 1.0
        of GG:
          result[index+0] = 0.8
          result[index+1] = 0.8
          result[index+2] = 0.8
          result[index+3] = 1.0
        of TU:
          result[index+0] = level_color.x * 0.5
          result[index+1] = level_color.y * 0.5
          result[index+2] = level_color.z * 0.5
          result[index+3] = 1.0
        of LV, LA, AJ, VJ, AA, JJ, LL, VV, IH, IL, IJ, AH, VH, II, HH:
          result[index+0] = 1.0
          result[index+1] = 0.0
          result[index+2] = 1.0
          result[index+3] = 1.0
        of P1:
          result[index+0] = 0.1
          result[index+1] = 0.1
          result[index+2] = 0.1
          result[index+3] = 1.0
        else:
          result[index+0] = level_color.x #1.0 #((y.float-COLOR_H) * (1.0/COLOR_D))
          result[index+1] = level_color.y #((y.float-COLOR_H) * (1.0/COLOR_D))
          result[index+2] = level_color.z #((y.float-COLOR_H) * (1.0/COLOR_D))
          result[index+3] = 1.0

type
  PatchKind = enum
    UpIn
    UpOut
    DownIn
    DownOut
  DiagDirection = enum
    Up
    Down
  Index = seq[cushort]

# This procedure generates the vertex sequence for a triangle strip that
# covers the given quadrilaterally-gridded surface.  The parameters 'N' and
# 'M' define the number of rows and columns of the grid, respectively.  The
# vertices are assumed to be in the positions given in the comment for the
# CheckGrid routine.  The 'patchtype' parameter determines which of four
# patche types to use - the normal vector can go into our out of the
# surface, and the diagonal can slope up or down going from left to right.
# On successful calculation, the routine will load 'Nverts' with the number
# of vertices in the triangle strip, and 'vertices' will contain the vertex
# indices (NOT geometry) of the triangle strip.  If this routine does not
# successfully return, 'Nverts' will be 0 and 'vertices' will be null. 
#
# Translated from Kubota Graphics C to nim by dctucker
proc setup_floor_index[T](level: seq[T]): Index =
  let N: int = w
  let M: int = h
  let patchtype = UpOut
  var Nverts: int

  var column: int
  var index: int
  var diagdir: DiagDirection  # Slope Direction of Patch Diagonal */
  var V1, V2: cushort         # Left & Right Vertex Indices */


  case patchtype
  of   UpIn :  diagdir = Up
  of   UpOut:  diagdir = Up
  of DownIn :  diagdir = Down
  of DownOut:  diagdir = Down
  #else:
  #  return newSeq[cushort](0)

  # Calculate the total number of vertices in the resultant triangle
  # strip.  This is equal to the number of vertices for each column
  # strip (2N(M-1)), plus the "filler" vertices to set up for the next
  # column strip (2(M-2)).  This is equal to 2[(N+1)(M-1) - 1].

  Nverts = 2 * ((N+1) * (M-1) - 1)

  # If the patch diagonal orientation and normal vector direction are
  # in conflict, then we specify the first vertex twice to reverse the
  # "out" direction of the triangle strip.  */

  if (patchtype == UpOut) or (patchtype == DownIn):
    inc Nverts

  result = newSeq[cushort](Nverts)

  # If the grid normal direction is opposite what is "natural" for the
  # triangle strip, then reverse the normal sense by specifying the first
  # vertex twice.

  index = 0

  if patchtype == UpOut:
    result[index] = N.cushort
    inc index
  elif patchtype == DownIn:
    result[index] = 0
    inc index

  # Generate the triangle strip by looping over each column.
  if diagdir == Up:
    V1 = N.cushort ; V2 = 0
  else:
    V1 = 0 ; V2 = N.cushort

  for column in 0..<M-1:
    if (column mod 2) == 0:
      for row in 0..<N:
        result[index] = V1
        inc index
        result[index] = V2
        inc index
        inc V1 ; inc V2
      dec V1 ; dec V2
    else:
      for row in 0..<N:
        result[index] = V1
        inc index
        result[index] = V2
        inc index
        dec V1 ; dec V2
      inc V1 ; inc V2

    if column == M-2: continue

    if (((column mod 2) == 0) and (diagdir == Up)) or (((column mod 2) == 1) and (diagdir == Down)):
      result[index] = V1
      inc index
      result[index] = V1
      inc index
      V2 = V1 + N.cushort
    else:
      result[index] = V2
      inc index
      result[index] = V2 + N.cushort
      inc index
      V1 = V2 + N.cushort

proc xlat_coord(x,z: float): (int,int) =
  return ((z.floor+oz.float).int, (x.floor+ox.float).int)

proc floor_height*(x,z: float): float =
  let (i,j) = xlat_coord(x,z)
  if i < 0 or j < 0 or i >= h-1 or j >= w-1: return EE.float
  return level_ref.data[i * w + j].float

proc slope*(x,z: float): Vec3f =
  let p0 = floor_height(x+0,z+0)
  let p1 = floor_height(x+1,z+0)
  let p2 = floor_height(x+0,z+1)
  #if p0 == 0 and p1 == 0 and p2 == 0:
  #  return vec3f(0, -1, 0)
  #let p3 = floor_height(x+1,z+1)
  #let dxz = p0 - p3
  let dx = p0 - p1
  let dz = p0 - p2

  return vec3f( dx, 0f, dz )
  #return vec3f( 0.5 * ((p0-p1) + (p3-p1)), 0f , 0.5 * ((p0-p2) + (p3-p2)) )

proc surface_normal*(x,z: float): Vec3f =
  let p0 = floor_height(x,z)
  let p1 = floor_height(x+1,z)
  let p2 = floor_height(x,z+1)
  let u = vec3f(1, p1-p0, 0)
  let v = vec3f(0, p2-p0, 1)
  result = v.cross(u).normalize()

proc mask*(x,z: float): CliffMask =
  let (i,j) = xlat_coord(x,z)
  if i < 0 or j < 0 or i >= h-1 or j >= w-1: return xx
  return level_ref.mask[i * w + j]

proc toString(x: float): string =
  x.formatFloat(ffDecimal,3)

proc point_height*(x,z: float): float =
  let h1 = floor_height( x+0, z+0 )
  let h2 = floor_height( x+1, z+0 )
  let h3 = floor_height( x+0, z+1 )
  let h4 = floor_height( x+1, z+1 )
  let ux = x - x.floor
  let uz = z - z.floor
  result  = h1 * (1-ux) * (1-uz)
  result += h2 *    ux  * (1-uz)
  result += h3 * (1-ux) * uz
  result += h4 * ux * uz
  #stdout.write ", floor = ", result.formatFloat(ffDecimal, 3)

proc average_height*(x,z: float): float =
  var n = 1
  var sum = floor_height(x,z)
  proc accum(v: float) =
    if v != EE and v > 0:
      sum += v
      inc n
  var i = 0
  while n < 100 and i < 200:
    inc i
    let ii = i.float
    accum floor_height(x+ii, z)
    accum floor_height(x-ii, z)
    accum floor_height(x  , z+ii)
    accum floor_height(x  , z-ii)
    for j in 1..i:
      let jj = j.float
      accum floor_height(x+ii, z+jj)
      accum floor_height(x-ii, z-jj)
      accum floor_height(x-ii, z+jj)
      accum floor_height(x+ii, z-jj)
  return sum / n.float

var floor_index*: Index
var floor_verts* : seq[cfloat]
var floor_colors*: seq[cfloat]
var current_level*: int

proc load_level*(n: int) =
  if 0 < n and n < levels.len:
    level_ref = levels[n]
    w = level_ref.width
    h = level_ref.height

    ox = level_ref.origin.x.float
    oy = level_ref.origin.y.float
    oz = level_ref.origin.z.float

    floor_verts  = setup_floor_points(level_ref.data, level_ref.mask)
    floor_colors = setup_floor_colors(level_ref.data, level_ref.mask, level_ref.color)
    floor_index = setup_floor_index level_ref.data

load_level 1


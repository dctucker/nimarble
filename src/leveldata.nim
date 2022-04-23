import glm
import sequtils
import strutils

const EE = 0


#const level_0 = @[
#
#  55 54  54 53  53 52
#  54 53  53 52  52 51
#
#  54 53  53 52  52 51
#  53 52  52 51  51 50
#
#  53 52  52 51  51 50 
#  52 51  51 50  50 49
#]
type CliffMask = enum
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

  #LA,AA,AJ,
  #LL,xx JJ,
  #LV,VV,VJ

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
    discard s.parseInt()
    result = true
  except:
    result = false

proc tsv_masks(line: string): seq[CliffMask] =
  var j = 0
  result = line.split("\t").map(proc(s:string):CliffMask =
    j += 1
    try:
      result = parseEnum[CliffMask](s)
    except:
      if s.len > 0 and s != "0":
        if not s.is_numeric():
          echo "Unrecognized mask at " & "," & $j & ": " & s
      result = xx
  )

const level_1_src = staticRead("../levels/1.tsv")
const level_2_src = staticRead("../levels/2.tsv")
const level_2_mask_src = staticRead("../levels/2mask.tsv")
const level_1_data = level_1_src.splitLines.map(tsv_floats).flatten()
const level_2_data = level_2_src.splitLines.map(tsv_floats).flatten()
const level_2_mask = level_2_mask_src.splitLines.map(tsv_masks).flatten()

type
  Level = ref object
    width, height: int
    origin_x, origin_z, origin_y: int
    data: seq[float]

let level_1 = Level(
  data: level_1_data,
  width: 114,
  height: 74,
  origin_x: 32,
  origin_z: 12,
  origin_y: 50,
  #AG13
)
let level_2 = Level(
  data: level_2_data,
  width: 158,
  height: 117,
  origin_x: 30,
  origin_z: 25,
  origin_y: 99,
  #AE26
)

var level_ref = level_2
var w = level_ref.width
var h = level_ref.height

const sky* = 120f
var ox* = level_ref.origin_x.float
var oy* = level_ref.origin_y.float
var oz* = level_ref.origin_z.float

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
      let y = level[offset]

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

proc setup_floor_points[T](level: seq[T]): seq[cfloat] =
  result = newSeq[cfloat](3 * w * h)
  for z in 0..<h:
    for x in 0..<w:
      let index = 3 * (w * z + x)
      let y = level[w * z + x]
      result[index+0] = (x.cfloat-ox).cfloat
      result[index+1] = y.cfloat
      result[index+2] = (z.cfloat-oz).cfloat

const ch = 4
proc setup_floor_colors[T](level: seq[T]): seq[cfloat] =
  #const COLOR_H = 44f
  #const COLOR_D = 56f - 44f
  const COLOR_H = 11f
  const COLOR_D = 99f - COLOR_H
  result = newSeq[cfloat](ch * w * h)
  for z in 0..<h:
    for x in 0..<w:
      let index = ch * (w * z + x)
      let y = level[w * z + x]
      if y == EE:
        result[index+0] = 0.0
        result[index+1] = 0.0
        result[index+2] = 0.0
        result[index+3] = 0.0
      else:
        result[index+0] = 1.0 #((y.float-COLOR_H) * (1.0/COLOR_D))
        result[index+1] = ((y.float-COLOR_H) * (1.0/COLOR_D))
        result[index+2] = ((y.float-COLOR_H) * (1.0/COLOR_D))
        result[index+3] = 1.0

var floor_verts*  = setup_floor_points level_ref.data
var floor_colors* = setup_floor_colors level_ref.data


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

var floor_index* = setup_floor_index level_ref.data

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


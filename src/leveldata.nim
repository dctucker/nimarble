import sequtils
import strutils

const EE = 0

const w = 114
const h = 74

#AG13
const ox* = 32
const oz* = 12

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

  #LA,AA,AJ,
  #LL,xx JJ,
  #LV,VV,VJ

const level_1_mask: seq[CliffMask] = @[
  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,VJ, VV,VV,VV, VV,VV,VV, VV,VV,xx,

  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LA,AA,AA, AA,AA,AA, AA,AA,xx,
  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx,

  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,VJ, VV,VV,VV, VV,VV,VJ, LL,xx,xx, xx,xx,VJ, VV,VV,VJ,

  xx,xx, xx,xx,xx, xx,xx,JJ, LA,AA,AA, AA,AA,AA, LA,xx,xx, xx,xx,JJ, LA,AA,AJ,
  xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,JJ,
  xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,JJ, LV,VV,VJ,

  xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,AJ, AA,AA,AA,
  xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,

  xx,xx, LA,AA,AA, AA,AA,AJ, LA,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,

  xx,xx, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, LL,xx,xx, xx,xx,VJ, VV,VV,VV, LV,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,

  xx,xx, xx,xx,xx, xx,xx,JJ, LA,AA,AJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,JJ, LL,xx,JJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
  xx,xx, xx,xx,xx, xx,xx,JJ, LV,VV,VJ, LL,xx,xx, xx,xx,xx, xx,xx,xx, xx,xx,xx,
]

proc flatten[T](input: seq[seq[T]]): seq[T] =
  for row in input:
    for value in row:
      result.add value

proc tsv_lines(line: string): seq[float] =
  result = line.split("\t").map(proc(s:string):float =
    if s.len() > 0: s.parseFloat
    else: 0
  )
  echo result.len

const level_1 = staticRead("../levels/1.tsv").splitLines.map(tsv_lines).flatten()
#echo level_1

proc get_value[T](level: seq[T], x,z: int): T =
  let index = w * z + x
  if index in level_1.low..level_1.high:
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
      result[index+0] = (x-ox).cfloat
      result[index+1] = y.cfloat
      result[index+2] = (z-oz).cfloat

const ch = 4
proc setup_floor_colors[T](level: seq[T]): seq[cfloat] =
  const COLOR_H = 44f
  const COLOR_D = 56f - 44f
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

var floor_verts* = setup_floor_points level_1
var floor_colors* = setup_floor_colors level_1


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
  else:
    return newSeq[cushort](0)

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

var floor_index* = setup_floor_index level_1

proc floor_height*(x,z: int): float =
  let i = (z+oz).int
  let j = (x+ox).int
  if i < 0 or j < 0 or i >= h-1 or j >= w-1: return EE.float
  return level_1[i * w + j].float


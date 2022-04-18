#var level_1* = @[
#  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,
#  0,  0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,  0,
#  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
#]

const EE = -20
var level_1* = @[
  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, 56,55,54, 53,53,53, EE,
  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, 55,52,53, 52,52,52, EE,
  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, 54,53,54, 51,51,51, EE,

  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, 53,52,51, 50,50,50, EE,
  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, 53,52,51, 50,50,50, EE,
  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, 53,52,51, 50,50,50, EE,

  EE,EE,EE, EE,EE,EE, 55,54,53, 53,53,53, 52,51,50, 49,49,49, EE,
  EE,EE,EE, EE,EE,EE, 54,53,52, 52,52,52, 51,50,49, 48,48,48, EE,
  EE,EE,EE, EE,EE,EE, 53,52,51, 51,51,51, 50,49,48, 47,47,47, EE,

  EE,EE,EE, EE,EE,EE, 53,52,51, 50,50,50, 49,48,47, 46,46,46, EE,
  EE,EE,EE, EE,EE,EE, 53,52,51, 50,50,50, 49,48,47, 46,46,46, EE,
  EE,EE,EE, EE,EE,EE, 53,52,51, 50,50,50, 49,48,47, 46,46,46, EE,

  56,55,54, 53,53,53, 52,51, 0, 49,49,49, 49,48,47, 46,46,46, EE,
  55,54,53, 52,52,52, 51,50,49, 48,48,48, 48,47,46, 45,45,45, EE,
  54,53,52, 51,51,51, 50,49,48, 47,47,47, 47,46,45, 44,44,44, EE,

  53,52,51, 50,50,50, 49,48,47, 46,46,46, 47,47,47, 46,45,44, EE,
  53,52,51, 50,50,50, 49,48,47, 46,46,46, 47,47,47, 46,45,44, EE,
  53,52,51, 50,50,50, 49,48,47, 46,46,46, 47,47,47, 46,45,44, EE,
  EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,EE,EE, EE,
]

let w = 19
let h = w

proc setup_floor_points[T](level: seq[T]): seq[cfloat] =
  result = newSeq[cfloat](3 * w * w)
  for z in 0..<w:
    for x in 0..<w:
      let index = 3 * (w * z + x)
      let y = level[w * z + x]
      result[index+0] = x.cfloat
      result[index+1] = y.cfloat
      result[index+2] = z.cfloat

proc setup_floor_colors[T](level: seq[T]): seq[cfloat] =
  const COLOR_H = 50f
  result = newSeq[cfloat](3 * w * w)
  for z in 0..<w:
    for x in 0..<w:
      let index = 3 * (w * z + x)
      let y = level[w * z + x]
      if y == EE:
        result[index+0] = 1.0
        result[index+1] = 0.8
        result[index+2] = 0.0
      else:
        result[index+0] = 0.5 + (y.float * (1.0/COLOR_H))
        result[index+1] = 0.5 + (y.float * (1.0/COLOR_H))
        result[index+2] = 0.5 + (y.float * (1.0/COLOR_H))

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

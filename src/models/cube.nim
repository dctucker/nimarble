import ../masks

let cube_verts* = @[
  vec3f( 0, 0, 0 ), #0
  vec3f( 0, 0, 1 ), #1
  vec3f( 0, 1, 0 ), #2
  vec3f( 0, 1, 1 ), #3
  vec3f( 1, 0, 0 ), #4
  vec3f( 1, 0, 1 ), #5
  vec3f( 1, 1, 0 ), #6
  vec3f( 1, 1, 1 ), #7
  vec3f( 0.5, 1, 0.5 ), #8
]

#[  0-----------4
    |\         /|
    | 2-------6 |
    | | \   / | |
    | |   8   | |
    | | /   \ | |
    | 3-------7 |
    |/         \|
    1-----------5  ]#

const cube_index* = @[
  0,
  0, 2, 4, 6, 6, 4,  # north
  4, 6, 5, 7, 7, 5,  # east
  5, 7, 1, 3, 3, 1,  # south
  1, 3, 0, 2,        # west
  #2, 6, 3, 3, 6, 7,  # top, broken from 2 to 7
  #2, 3, 7, 7, 2, 6,  # top, broken from 3 to 6
  2, 3, 8, 2, 8, 6, 6, 8, 7, 7, 8, 3, # four triangles
  3, 1, 1, 5, 0, 4, 4,     # reset
]

let cube_colors* = @[
  0,
  3, 3, 3, 3, 0, 0,  # north
  4, 4, 4, 4, 0, 0,  # east
  5, 5, 5, 5, 0, 0,  # south
  2, 2, 2, 2,        # west
  #1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  0, 0, 6, 6, 6, 6, 0,
]
proc all_cube_index(n: int): seq[int] =
  for o,i in cube_index.pairs:
    if i == 8:
      result.add o

const top_points* = @[ 23, 25, 24, 26, 27, 28, 29, 30, 31, 32, 33, 34 ]
const middle_points* = all_cube_index(8)
assert cube_colors.len == cube_index.len

#var cube_normals*: seq[Vec3f]
#for v in cube_verts:
#  cube_normals.add vec3f(v.x.float - 0.5, v.y.float - 0.5, v.z.float - 0.5).normalize()

#const ch = 4
#var cube_colors* = newSeq[cfloat](cube.len * ch div d)
#for i in 0..<cube_index.len:
#  let phase = (i.cfloat/(cube.len / ch))
#  cube_colors[ch*i+0] = 0.0f * phase
#  cube_colors[ch*i+1] = 0.5f * phase
#  cube_colors[ch*i+2] = 1.0f * (1.0-phase)
#  cube_colors[ch*i+3] = 0.5f

proc cube_normal*(color_w: int): Vec3f =
  result = case color_w
  of 3: vec3f(  0,  0, -1 )
  of 4: vec3f( +1,  0,  0 )
  of 5: vec3f(  0,  0, +1 )
  of 2: vec3f( -1,  0,  0 )
  of 1: vec3f(  0,  1,  0 )
  else: vec3f(  0, -1,  0 )

#proc genCubeUvs: seq[Vec2f] =
#  for i in cube_index:
#    var vec = cube_verts[i]
#    result.add vec2f( vec.x, vec.z )

proc genRampVerts: seq[Vec3f] =
  const margin = 1#0.98
  for i in cube_index:
    var vec = cube_verts[i]
    result.add vec3f( vec.x * margin, vec.y - 1.0, vec.z * margin)

proc genRampUvs: seq[Vec3f] =
  for w,v in cube_index.pairs:
    var color_w = cube_colors[w]
    var vec = cube_verts[v]
    case color_w
    of 3: # north
      result.add vec3f( 1-vec.x, 1-vec.y, RH.ord + 1)
    of 4: # east
      result.add vec3f( vec.z, 1-vec.y, RI.ord + 1)
    of 5: # south
      result.add vec3f( vec.x, 1-vec.y, RH.ord + 1)
    of 2: # west
      result.add vec3f( 1-vec.z, 1-vec.y, RI.ord + 1)
    else:
      result.add vec3f( vec.x, vec.z, IH.ord + 1 )

proc genRampNormals: seq[Vec3f] =
  for color_w in cube_colors:
    result.add cube_normal(color_w)

proc genRampColors: seq[Vec4f] =
  for color_w in cube_colors:
    case color_w
    of 3,4,5,2:
      result.add vec4f(0.0, 0.73, 0.67, 1)
    else:
      result.add vec4f(0.6, 0.6, 0.6, 1)

proc genRampIndex: seq[Ind] =
  for i,j in cube_index.pairs:
    result.add i.Ind

var ramp*         = toCfloats( genRampVerts(), 3 )
var ramp_colors*  = toCfloats( genRampColors(), 4 )
var ramp_normals* = toCfloats( genRampNormals(), 3 )
var ramp_uvs*     = toCfloats( genRampUvs(), 3 )
var ramp_index*   = genRampIndex()

proc genCursorColors: seq[Vec4f] =
  for n, color_w in cube_colors.pairs:
    case color_w
    of 3,4,5,2:
      result.add vec4f(0.0, 0.0, 0.3, 0.125)
    of 1,6:
      let v = cube_verts[cube_index[n]]
      if v.x <= 0.5 and v.z <= 0.5:
        result.add vec4f(1.0, 1.0, 1.000, 0.375)
      else:
        result.add vec4f(0.0, 0.0, 0.25, 0.03125)
    else:
      result.add vec4f(0.0, 0.0, 0.0, 0)

var cursor*         = toCfloats( genRampVerts(), 3 )
var cursor_colors*  = toCfloats( genCursorColors(), 4 )
var cursor_normals* = toCfloats( genRampNormals(), 3 )
var cursor_index*   = genRampIndex()

proc genSelectorColors: seq[Vec4f] =
  for color_w in cube_colors:
    case color_w
    of 3,4,5,2:
      result.add vec4f(0.0, 0.0, 0.3, 0.25)
    of 1,6:
      result.add vec4f(0.0, 0.0, 0.25, 0.5)
    else:
      result.add vec4f(0.0, 0.0, 0.0, 0)

proc genBrushSelectorColors: seq[Vec4f] =
  for color_w in cube_colors:
    case color_w
    of 3,4,5,2:
      result.add vec4f( 0.3, 0.0, 0.0, 0.25)
    of 1,6:
      result.add vec4f(0.25, 0.0, 0.0, 0.5)
    else:
      result.add vec4f( 0.0, 0.0, 0.0, 0)

var selector*         = toCfloats( genRampVerts(), 3 )
var selector_colors*  = toCfloats( genSelectorColors(), 4 )
var brush_colors*  = toCfloats( genBrushSelectorColors(), 4 )
var selector_normals* = toCfloats( genRampNormals(), 3 )
var selector_index*   = genRampIndex()


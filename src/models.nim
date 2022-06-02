import glm
from wrapper import Ind

proc toCfloats(vecs: seq[Vec4f], dim: int = 3): seq[cfloat] =
  result = newSeqOfCap[cfloat](dim * vecs.len)
  for vec in vecs:
    if dim >= 1: result.add vec.x
    if dim >= 2: result.add vec.y
    if dim >= 3: result.add vec.z
    if dim >= 4: result.add vec.w

proc toCfloats(vecs: seq[Vec3f], dim: int = 3): seq[cfloat] =
  result = newSeqOfCap[cfloat](dim * vecs.len)
  for vec in vecs:
    if dim >= 1: result.add vec.x
    if dim >= 2: result.add vec.y
    if dim >= 3: result.add vec.z

proc toInds(ints: seq[int]): seq[Ind] =
  for i in ints:
    result.add i.Ind


#[

  0---------4
  |\       /|
  | 2-----6 |
  | |     | |
  | |     | |
  | 3-----7 |
  |/       \|
  1---------5

]#

let cube_verts* = @[
  vec3f( 0, 0, 0 ), #0
  vec3f( 0, 0, 1 ), #1
  vec3f( 0, 1, 0 ), #2
  vec3f( 0, 1, 1 ), #3
  vec3f( 1, 0, 0 ), #4
  vec3f( 1, 0, 1 ), #5
  vec3f( 1, 1, 0 ), #6
  vec3f( 1, 1, 1 ), #7
]

let cube_index* = @[
  0,
  0, 2, 4, 6, 6, 4,  # north
  4, 6, 5, 7, 7, 5,  # east
  5, 7, 1, 3, 3, 1,  # south
  1, 3, 0, 2,        # west
  2, 6, 3, 7, 7,     # top
  7, 5, 5, 4, 4,     # reset
]

let cube_colors* = @[
  0,
  3, 3, 3, 3, 0, 0,
  4, 4, 4, 4, 0, 0,
  5, 5, 5, 5, 0, 0,
  2, 2, 2, 2,
  1, 1, 1, 1, 0,
  0, 0, 0, 0, 0,
]
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
  else: vec3f(  0,  0,  0 )

proc genRampVerts: seq[Vec3f] =
  const margin = 0.98
  for i in cube_index:
    var vec = cube_verts[i]
    result.add vec3f( vec.x * margin, vec.y - 1.0, vec.z * margin)

proc genRampNormals: seq[Vec3f] =
  for color_w in cube_colors:
    result.add cube_normal(color_w)

proc genRampColors: seq[Vec4f] =
  for color_w in cube_colors:
    case color_w
    of 3,4,5,2:
      result.add vec4f(0.0, 0.5, 0.5, 1)
    else:
      result.add vec4f(0.5, 0.5, 0.5, 1)

proc genRampIndex: seq[Ind] =
  for i,j in cube_index.pairs:
    result.add i.Ind

var ramp*         = toCfloats( genRampVerts(), 3 )
var ramp_colors*  = toCfloats( genRampColors(), 4 )
var ramp_normals* = toCfloats( genRampNormals(), 3 )
var ramp_index*   = genRampIndex()


const player_radius* = 0.625f
proc uvSphereVerts*(segments, rings: int): seq[cfloat] =
  result = newSeqOfCap[cfloat](3 * (segments+1) * rings)

  for j in 0 .. segments:
    let
      beta = (j / segments) * 2 * 3.14159265
      x = cos(beta).float32
      y = sin(beta).float32

    for i in 0 ..< rings:
      let
        alpha = (i / (rings-1)) * 3.14159265
        h = cos(alpha).float32
        r = sin(alpha).float32

      result.add player_radius * x * r
      result.add player_radius * y * r
      result.add player_radius * h

proc uvSphereNormals*(segments, rings: int): seq[cfloat] =
  result = newSeqOfCap[cfloat](3 * (segments+1) * rings)

  for j in 0 .. segments:
    let
      beta = (j / segments) * 2 * 3.14159265
      x = cos(beta).float32
      y = sin(beta).float32

    for i in 0 ..< rings:
      let
        alpha = (i / (rings-1)) * 3.14159265
        h = cos(alpha).float32
        r = sin(alpha).float32

      result.add x * r
      result.add y * r
      result.add h

proc uvSphereElements*(segments, rings: int): seq[Ind] =
  result = newSeqOfCap[Ind]((segments+1) * rings)

  for segment in 0 ..< segments:
    for ring in 0 ..< rings - 1:
      let
        i1 = Ind( ring +     segment * rings )
        i2 = Ind( ring + 1 + segment * rings )
        i3 = Ind( ring +     segment * rings + rings )
        i4 = Ind( ring + 1 + segment * rings + rings )
      result.add([i1,i2,i3,i3,i2,i4])

proc uvSphereColors*(segments, rings: int): seq[cfloat] =
  result = newSeqOfCap[cfloat](4 * (segments+1) * rings)

  const opacity = 0.875
  for j in 0 .. segments:
    let beta = (j / segments).float32

    for i in 0 ..< rings:
      let alpha = (i / (rings-1)).float32

      if alpha < 0.10 or alpha >= 0.90:
        result.add 0.0
        result.add 0.0
        result.add 0.0
        result.add opacity
      elif alpha < 0.5:
        if beta < 0.25:
          result.add 0.0
          result.add 1.0
          result.add 0.0
          result.add opacity
        elif beta < 0.5:
          result.add 0.0
          result.add 0.0
          result.add 1.0
          result.add opacity
        elif beta < 0.75:
          result.add 1.0
          result.add 1.0
          result.add 0.0
          result.add opacity
        else:
          result.add 1.0
          result.add 0.0
          result.add 1.0
          result.add opacity
      else:
        if beta < 0.25:
          result.add 1.0
          result.add 0.0
          result.add 0.0
          result.add opacity
        elif beta < 0.5:
          result.add 0.0
          result.add 1.0
          result.add 1.0
          result.add opacity
        elif beta < 0.75:
          result.add 1.0
          result.add 0.5
          result.add 0.0
          result.add opacity
        else:
          result.add 0.5
          result.add 0.0
          result.add 1.0
          result.add opacity

  for i, v in result.mpairs:
    if i mod 4 == 3: continue
    v *= 0.5



proc uvSphereColors(nseg, nrings: int, color: Vec4f): seq[cfloat] =
  for a in 0..nseg:
    for b in 0..nrings:
      result.add color.x
      result.add color.y
      result.add color.z
      result.add color.w

const nseg = 32
const nrings = 16
var sphere* = uvSphereVerts(nseg,nrings)
var sphere_index* = uvSphereElements(nseg,nrings)
var sphere_normals* = uvSphereNormals(nseg,nrings)
var sphere_colors* = uvSphereColors(nseg,nrings)
var yum_colors* = uvSphereColors(nseg,nrings, vec4f(0.1, 0.8, 0.1, 1.0))
var enemy_colors* = uvSphereColors(nseg,nrings, vec4f(0.0, 0.1, 0.0, 0.9))

proc cylinderVertices*(segments: int, radius: float32 = 1, length: float32 = 1): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)
  let l2 = length / 2f

  result[2 * (segments+1)]     = vec4f(0,0,-l2,1)
  result[3 * (segments+1) + 1] = vec4f(0,0, l2,1)

  for j in 0 .. segments:
    let
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32
      y = sin(beta).float32
      top =    vec4f(vec2f(x,y) * radius,  l2, 1)
      bottom = vec4f(vec2f(x,y) * radius, -l2, 1)

    result[2*j+0] = bottom
    result[2*j+1] = top
    result[2*(segments+1) + 1 + j] = bottom
    result[3*(segments+1) + 2 + j] = top

proc cylinderNormals*(segments: int, topRadius: float32 = 1): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1)] = vec4f(0,0,-1, 0)
  result[3 * (segments+1) + 1] = vec4f(0,0, 1, 0)

  let n = vec2f(2,1-topRadius).normalize

  for j in 0 .. segments:
    let
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32
      y = sin(beta).float32

    result[2*j+0] = vec4f( vec2(x, y) * n.x, n.y, 0)
    result[2*j+1] = vec4f( vec2(x, y) * n.x, n.y, 0)
    result[2*(segments+1) + 1 + j] = vec4f(0,0,-1, 0)
    result[3*(segments+1) + 2 + j] = vec4f(0,0, 1, 0)

proc cylinderTexCoords*(segments: int): seq[Vec2f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1)] = vec2f(0.5f)
  result[3 * (segments+1) + 1] = vec2f(0.5f)

  for j in 0 .. segments:
    let
      u = (j / segments).float32
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32 * 0.5f + 0.5f
      y = sin(beta).float32 * 0.5f + 0.5f

    result[2*j+0] = vec2f(u, 0)
    result[2*j+1] = vec2f(u, 1)
    result[2*(segments+1) + 1 + j] = vec2f(x,y)
    result[3*(segments+1) + 2 + j] = vec2f(x,y)

proc cylinderColors*(segments: int, color: Vec3f): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1) + 0] = vec4f(1f, 1f, 1f, 1)
  result[3 * (segments+1) + 1] = vec4f(1f, 1f, 1f, 1)

  for j in 0 .. segments:
    let
      u = (j / segments).float32
      beta = (j / segments) * 2 * PI
      x = cos(45f.radians + beta).float32 * 0.5f + 0.5f
      y = sin(beta).float32 * 0.5f + 0.5f

    let contrast = 0.6
    let s = y * contrast + (1f - contrast)
    result[2*j+0] = vec4f(s, s, s, 1)
    result[2*j+1] = vec4f(s, s, s, 1)
    result[2*(segments+1) + 1 + j] = vec4f(s,s,s, 1)
    result[3*(segments+1) + 2 + j] = vec4f(s,s,s, 1)

  for c in result.mitems:
    c.x *= color.x
    c.y *= color.y
    c.z *= color.z

proc cylinderIndices*(segments: int): seq[Ind] {.compileTime.} =
  result.newSeq(0)

  for i in 0 ..< segments:
    let
      i1 = Ind( i * 2 + 0 )
      i2 = Ind( i * 2 + 1 )
      i3 = Ind( i * 2 + 2 )
      i4 = Ind( i * 2 + 3 )

    result.add([i1,i3,i2,i2,i3,i4])

  var base = Ind(2 * (segments+1))

  for i in 0 ..< Ind(segments):
    let ii = i.Ind
    result.add( [ base , base + ii + 2, base + ii + 1 ] )

  base = Ind(3 * (segments+1) + 1)

  for i in 0 ..< segments:
    let ii = i.Ind
    result.add( [ base, base + ii + 1, base + ii + 2 ] )

var yum* = toCfloats cylinderVertices(nseg, 0.5f)

const rail_segs = 6
var single_rail*         = toCfloats(   cylinderVertices(rail_segs, 0.25f)      )
var single_rail_normals* = toCfloats(    cylinderNormals(rail_segs)             )
var single_rail_colors*  = toCfloats(     cylinderColors(rail_segs, vec3f(0.7f, 0.1f, 0f))         , 4 )
var single_rail_index*   =          (    cylinderIndices(rail_segs)             )

const piston_segs = 16
var piston_verts*        = toCfloats(   cylinderVertices(piston_segs, 0.375f)    )
var piston_normals*      = toCfloats(    cylinderNormals(piston_segs)           )
var piston_colors*       = toCfloats(     cylinderColors(piston_segs, vec3f(0.6f, 0.61f, 0.61f))       , 4 )
var piston_index*        =          (    cylinderIndices(piston_segs)           )

#for i, v in piston_verts.mpairs:
#  if i mod 3 == 2: continue
#  v += 0.5f

#[

   2 ___ 3
    /   \
 1 /     \ 4
  |   0   |
  |       |
 8 \     / 5
    \___/
   7     6

]#
var acid_verts*: seq[cfloat] = @[
   0.0f , 0.0f ,  0.0f ,
  -0.8f , 0.1f , -0.5f ,
  -0.5f , 0.1f , -0.8f ,
  +0.5f , 0.1f , -0.8f ,
  +0.8f , 0.1f , -0.5f ,
  +0.8f , 0.1f , +0.5f ,
  +0.5f , 0.1f , +0.8f ,
  -0.5f , 0.1f , +0.8f ,
  -0.8f , 0.1f , +0.5f ,
]
var acid_index*: seq[Ind] = @[
  1.Ind,
  2.Ind,
  0.Ind,
  3.Ind,
  4.Ind,
  0.Ind,
  5.Ind,
  6.Ind,
  0.Ind,
  7.Ind,
  8.Ind,
  0.Ind,
  1.Ind,
]
var acid_colors*: seq[cfloat] = @[
  0.2f, 0.8f, 0.1f, 0.5f,
  0.2f, 0.7f, 0.2f, 0.6f,
  0.1f, 0.8f, 0.1f, 0.6f,
  0.1f, 0.7f, 0.2f, 0.5f,
  0.1f, 0.8f, 0.1f, 0.6f,
  0.1f, 0.7f, 0.1f, 0.6f,
  0.2f, 0.8f, 0.1f, 0.6f,
  0.2f, 0.7f, 0.2f, 0.5f,
  0.1f, 0.8f, 0.1f, 0.6f,
  0.1f, 0.7f, 0.2f, 0.6f,
  0.1f, 0.8f, 0.1f, 0.6f,
  0.1f, 0.7f, 0.1f, 0.5f,
  0.1f, 0.8f, 0.1f, 0.6f,
]
var acid_normals*: seq[cfloat] = @[
  -0.7071067690849304f, 0.7071067690849304f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
  0f, +1f, 0f,
]



#[ cube under sine
      2_____3
      /|   /|
     / |  / |
   4/____/5 |
    |  |_|__|
    | 0  |  /1
    |    | /
    |____|/
   6     7
]#
const wave_res* = 16
const wave_len* = 12
const wave_angles* = wave_res * wave_len
const wave_nverts* = 12
const wave_ninds*  = 12

proc wave_func[T](t: T): T =
  var y0, y1: float
  #[ sinusoidal
  result = sin(radians t + 180)
  #]#

  #[ hyperbolic secant
  result = 1f / cosh(radians(4*(t - 180)))
  #]#

  # gaussian
  const a = 1f
  const b = 2f
  const c = 2f/5f
  result = a * exp -pow(t.radians-b, 2f) / (2f*c*c)
  #]#

  const epsilon = 1/256f
  if result < epsilon: result = 0

proc gen_wave_verts: seq[Vec3f] {.compileTime.} =
  for a in 0 ..< wave_len:
    for b in 0 ..< wave_res:
      let x = a * wave_res + b
      let x0 = (x + 0).float
      let x1 = (x + 1).float
      let t0 = 360f * x0 / wave_len.float / wave_res.float
      let t1 = 360f * x1 / wave_len.float / wave_res.float

      let z0 = 1f/256f
      let z1 = 255f/256f

      var y0 = wave_func t0
      var y1 = wave_func t1

      result.add vec3f(x0,  0, z0)
      result.add vec3f(x1,  0, z0)
      result.add vec3f(x0, y0, z0)
      result.add vec3f(x1, y1, z0)
      result.add vec3f(x0, y0,  0)
      result.add vec3f(x1, y1,  0)
      result.add vec3f(x0, y0,  1)
      result.add vec3f(x1, y1,  1)
      result.add vec3f(x0, y0, z1)
      result.add vec3f(x1, y1, z1)
      result.add vec3f(x0,  0, z1)
      result.add vec3f(x1,  0, z1)

proc gen_wave_colors: seq[Vec4f] {.compileTime.} =
  for a in 0 ..< wave_len:
    for b in 0 ..< wave_res:
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )

      let x = a * wave_res + b
      let x0 = (x + 0).float
      let x1 = (x + 1).float
      let t0 = 360f * x0 / wave_len.float / wave_res.float
      let t1 = 360f * x1 / wave_len.float / wave_res.float

      var y0 = wave_func t0
      var y1 = wave_func t1

      let z0 = 1f/256f
      let z1 = 255f/256f

      let sx = 1f/wave_res
      let sy = 3f
      let a = vec3f(x0 * sx, y0 * sy, z0)
      let b = vec3f(x1 * sx, y1 * sy, z0)
      let c = vec3f(x0 * sx, y0 * sy, z1)
      let d = vec3f(x1 * sx, y1 * sy, z1)

      let n0 = -normalize (b - a).cross(c - a)
      let n1 = -normalize (d - b).cross(c - b)
      let v = n0.y

      result.add vec4f( 0.0, 0.6 * v, 0.6 * v, 1.0 )
      result.add vec4f( 0.0, 0.6 * v, 0.6 * v, 1.0 )
      result.add vec4f( 0.0, 0.6 * v, 0.6 * v, 1.0 )
      result.add vec4f( 0.0, 0.6 * v, 0.6 * v, 1.0 )

      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )
      result.add vec4f( 0.1, 0.6, 0.6, 1.0 )

proc gen_wave_normals: seq[Vec3f] {.compileTime.} =
  for a in 0 ..< wave_len:
    for b in 0 ..< wave_res:
      let x = a * wave_res + b
      let x0 = (x + 0).float
      let x1 = (x + 1).float
      let t0 = 360f * x0 / wave_len.float / wave_res.float
      let t1 = 360f * x1 / wave_len.float / wave_res.float

      var y0 = wave_func t0
      var y1 = wave_func t1

      let z0 = 1f/256f
      let z1 = 255f/256f

      let sx = 1f/wave_res
      let sy = 3f
      let a = vec3f(x0 * sx, y0 * sy, z0)
      let b = vec3f(x1 * sx, y1 * sy, z0)
      let c = vec3f(x0 * sx, y0 * sy, z1)
      let d = vec3f(x1 * sx, y1 * sy, z1)

      let n0 = -normalize (b - a).cross(c - a)
      let n1 = -normalize (d - b).cross(c - b)

      result.add vec3f( -1,  0, -1 ).normalize
      result.add vec3f( +1,  0, -1 ).normalize
      result.add vec3f( -1,  0, -1 ).normalize
      result.add vec3f( +1,  0, -1 ).normalize
      result.add n0
      result.add n1
      result.add n0
      result.add n1
      result.add vec3f( -1,  0, +1 ).normalize
      result.add vec3f( +1,  0, +1 ).normalize
      result.add vec3f( -1,  0, +1 ).normalize
      result.add vec3f( +1,  0, +1 ).normalize

proc gen_wave_index: seq[Ind] {.compileTime.} =
  for a in 0 ..< wave_angles:
    let v = a * wave_nverts
    for n in 0 ..< wave_nverts:
      result.add Ind v + n

var wave_verts*   = toCfloats( gen_wave_verts()   , 3)
var wave_colors*  = toCfloats( gen_wave_colors()  , 4)
var wave_normals* = toCfloats( gen_wave_normals() , 3)
var wave_index*   =          ( gen_wave_index()   )

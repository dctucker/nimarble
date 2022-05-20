import glm
from wrapper import Ind

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
  vec3i( 0, 0, 0 ), #0
  vec3i( 0, 0, 1 ), #1
  vec3i( 0, 1, 0 ), #2
  vec3i( 0, 1, 1 ), #3
  vec3i( 1, 0, 0 ), #4
  vec3i( 1, 0, 1 ), #5
  vec3i( 1, 1, 0 ), #6
  vec3i( 1, 1, 1 ), #7
]
echo cube_verts.len

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

iterator cube_vert*(): Vec3i =
  for i in cube_index:
    yield cube_verts[i]


#const ch = 4
#var cube_colors* = newSeq[cfloat](cube.len * ch div d)
#for i in 0..<cube_index.len:
#  let phase = (i.cfloat/(cube.len / ch))
#  cube_colors[ch*i+0] = 0.0f * phase
#  cube_colors[ch*i+1] = 0.5f * phase
#  cube_colors[ch*i+2] = 1.0f * (1.0-phase)
#  cube_colors[ch*i+3] = 0.5f

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

  const opacity = 0.7
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

proc toCfloats(vecs: seq[Vec4f], dim: int = 3): seq[cfloat] =
  result = newSeqOfCap[cfloat](dim * vecs.len)
  for vec in vecs:
    if dim >= 1: result.add vec.x
    if dim >= 2: result.add vec.y
    if dim >= 3: result.add vec.z
    if dim >= 4: result.add vec.w

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

proc cylinderColors*(segments: int): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1)] = vec4f(0.5f, 0.5f, 0, 1)
  result[3 * (segments+1) + 1] = vec4f(0.5f, 0.5f, 0, 1)

  for j in 0 .. segments:
    let
      u = (j / segments).float32
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32 * 0.5f + 0.5f
      y = sin(beta).float32 * 0.5f + 0.5f

    result[2*j+0] = vec4f(u, 0, 0, 1)
    result[2*j+1] = vec4f(u, 1, 0, 1)
    result[2*(segments+1) + 1 + j] = vec4f(x,y, 0, 1)
    result[3*(segments+1) + 2 + j] = vec4f(x,y, 0, 1)

  for c in result.mitems:
    c.x = 0.7
    c.y = 0.1
    c.z = 0.0

proc cylinderIndices*(segments: int): seq[Ind] =
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

var single_rail*         = toCfloats(         cylinderVertices(6, 0.25f)      )
var single_rail_normals* = toCfloats(          cylinderNormals(6)      )
var single_rail_colors*  = toCfloats(           cylinderColors(6)         , 4 )
var single_rail_index*   =          (          cylinderIndices(6)             )

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

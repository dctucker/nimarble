import glm
from types import Ind

#[

  0         4
    2     6


    3     7
  1         5

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
  0, 2, 4, 6,     # north
  4, 6, 5, 7,     # east
  5, 7, 1, 3,     # south
  1, 3, 0, 2,     # west
  2, 6, 3, 7,     # top
  7, 5, 5, 4, 4,  # reset
]

let cube_colors* = @[
  0,
  3, 4, 3, 3,
  2, 2, 2, 2,
  3, 3, 3, 3,
  2, 2, 2, 4,
  1, 1, 1, 1,
  0, 0, 0, 0, 0,
]
assert cube_colors.len == cube_index.len

var cube_normals*: seq[Vec3f]
for v in cube_verts:
  cube_normals.add vec3f(v.x.float - 0.5, v.y.float - 0.5, v.z.float - 0.5).normalize()

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

proc uvSphereEnemy(nseg, nrings: int): seq[cfloat] =
  const opacity = 0.8
  for a in 0..nseg:
    for b in 0..nrings:
      result.add 0.3
      result.add 0.7
      result.add 0.0
      result.add opacity

const nseg = 32
const nrings = 16
var sphere* = uvSphereVerts(nseg,nrings)
var sphere_index* = uvSphereElements(nseg,nrings)
var sphere_normals* = uvSphereNormals(nseg,nrings)
var sphere_colors* = uvSphereColors(nseg,nrings)
var sphere_enemy_colors* = uvSphereEnemy(nseg,nrings)

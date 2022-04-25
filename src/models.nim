import glm
from leveldata import Ind

var cube* = @[
  -1.0f, -1.0f, -1.0f, # triangle 1 : begin
  -1.0f, -1.0f, +1.0f,
  -1.0f, +1.0f, +1.0f, # triangle 1 : end
  +1.0f, +1.0f, -1.0f, # triangle 2 : begin
  -1.0f, -1.0f, -1.0f,
  -1.0f, +1.0f, -1.0f, # triangle 2 : end
  +1.0f, -1.0f, +1.0f,
  -1.0f, -1.0f, -1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, +1.0f, -1.0f,
  +1.0f, -1.0f, -1.0f,
  -1.0f, -1.0f, -1.0f,
  -1.0f, -1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  -1.0f, +1.0f, -1.0f,
  +1.0f, -1.0f, +1.0f,
  -1.0f, -1.0f, +1.0f,
  -1.0f, -1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  -1.0f, -1.0f, +1.0f,
  +1.0f, -1.0f, +1.0f,
  +1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, +1.0f, -1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, +1.0f,
  +1.0f, +1.0f, +1.0f,
  +1.0f, +1.0f, -1.0f,
  -1.0f, +1.0f, -1.0f,
  +1.0f, +1.0f, +1.0f,
  -1.0f, +1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  +1.0f, +1.0f, +1.0f,
  -1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, +1.0f,
]

const d = 3
var cube_index* = newSeq[Ind](cube.len div d)
for i in 0..<cube_index.len:
  cube_index[i] = i.Ind

const ch = 4
var cube_colors* = newSeq[cfloat](cube.len * ch div d)
for i in 0..<cube_index.len:
  let phase = (i.cfloat/(cube.len / ch))
  cube_colors[ch*i+0] = 0.0f * phase
  cube_colors[ch*i+1] = 0.5f * phase
  cube_colors[ch*i+2] = 1.0f * (1.0-phase)
  cube_colors[ch*i+3] = 0.5f

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

  const opacity = 0.8
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

const nseg = 32
const nrings = 16
var sphere* = uvSphereVerts(nseg,nrings)
var sphere_index* = uvSphereElements(nseg,nrings)
var sphere_colors* = uvSphereColors(nseg,nrings)


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

var cube_index* = newSeq[cushort](cube.len div 3)
for i in 0..<cube_index.len:
  cube_index[i] = i.cushort

var cube_colors* = newSeq[cfloat](36*3)
for i in 0..<cube_index.len:
  let phase = (i.cfloat/(cube.len / 3))
  cube_colors[3*i+0] = 0.0f * phase
  cube_colors[3*i+1] = 1.0f * phase
  cube_colors[3*i+2] = 0.5f * (1.0-phase)



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
var cube_index* = newSeq[cushort](cube.len div d)
for i in 0..<cube_index.len:
  cube_index[i] = i.cushort

const ch = 4
var cube_colors* = newSeq[cfloat](cube.len * ch div d)
for i in 0..<cube_index.len:
  let phase = (i.cfloat/(cube.len / ch))
  cube_colors[ch*i+0] = 0.0f * phase
  cube_colors[ch*i+1] = 0.5f * phase
  cube_colors[ch*i+2] = 1.0f * (1.0-phase)
  cube_colors[ch*i+3] = 0.5f


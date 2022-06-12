var skybox_verts*: seq[cfloat] = @[
  -1.0f, -1.0f, -1.0f, #0
  -1.0f, -1.0f, +1.0f, #1
  -1.0f, +1.0f, -1.0f, #2
  -1.0f, +1.0f, +1.0f, #3
  +1.0f, -1.0f, -1.0f, #4
  +1.0f, -1.0f, +1.0f, #5
  +1.0f, +1.0f, -1.0f, #6
  +1.0f, +1.0f, +1.0f, #7
]

const skybox_idx: seq[int] = @[
  3, 7, 1, 5, 4, 7, 6,
  3, 2, 1, 0, 4, 2, 6,
]

var skybox_index* = skybox_idx.toInds()

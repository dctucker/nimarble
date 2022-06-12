var skybox_verts*: seq[cfloat] = @[
  -1.0f, -1.0f, -1.0f,
  -1.0f, -1.0f, +1.0f,
  -1.0f, +1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, -1.0f, +1.0f,
  +1.0f, +1.0f, -1.0f,
  +1.0f, +1.0f, +1.0f,
]

const skybox_idx: seq[int] = @[
  2, 0, 4, 4, 6, 2,
  1, 0, 2, 2, 3, 1,
  4, 5, 7, 7, 6, 4,
  1, 3, 7, 7, 5, 1,
  2, 6, 7, 7, 3, 2,
  0, 1, 4, 4, 1, 5,
]
var skybox_index* = skybox_idx.toInds()

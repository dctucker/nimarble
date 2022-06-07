
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

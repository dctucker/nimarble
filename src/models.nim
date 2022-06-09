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

#proc toInds(ints: seq[int]): seq[Ind] =
#  for i in ints:
#    result.add i.Ind

include models/[
  cube     ,
  sphere   ,
  cylinder ,
  octagon  ,
  wave     ,
]

proc genBox(n: int): seq[Vec3f] =
  result = newSeqOfCap[Vec3f](n*n)
  for i in 1..n:
    for j in 1..n:
      if (i == 1) or (j == 1) or (i == n) or (j == n):
        result.add vec3f(0,0,0)
      else:
        result.add vec3f(1,1,1)

const box_size* = 16
const box = genBox(box_size)
var box_texture* = toCfloats( box, 3 )

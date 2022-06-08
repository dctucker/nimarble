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

include models/[
  cube     ,
  sphere   ,
  cylinder ,
  octagon  ,
  wave     ,
]


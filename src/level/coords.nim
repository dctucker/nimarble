
proc xlat_coord*[T:Ordinal](level: Level, x,z: T): (int,int) =
  return ((z+level.origin.z).int, (x+level.origin.x).int)

proc xlat_coord*(level: Level, x,z: float): (int,int) =
  return ((z.floor+level.origin.z.float).int, (x.floor+level.origin.x.float).int)

proc has_coord*[T](level: Level, i,j: T): bool =
  result = i >= 0            and
           j >= 0            and
           i <  level.height and
           j <  level.width  and
           j >= i            and
           j - i <= level.span

iterator coords*(level: Level): (int, int) =
  for i in 0 ..< level.height:
    for j in 0 ..< level.width:
      yield (i,j)
iterator coords*(level: Level, zone: Zone): (int, int) =
  let (i1,j1) = level.xlat_coord(zone.rect.x, zone.rect.y)
  let (i2,j2) = level.xlat_coord(zone.rect.z, zone.rect.w)
  for i in i1 .. i2:
    for j in j1 .. j2:
      yield (i,j)
iterator indexed_coords*(level: Level, zone: Zone): (int, int, int) =
  var n = 0
  let (i1,j1) = level.xlat_coord(zone.rect.x, zone.rect.y)
  let (i2,j2) = level.xlat_coord(zone.rect.z, zone.rect.w)
  for i in i1 .. i2:
    for j in j1 .. j2:
      yield (n,i,j)
      inc n


proc data_at(level: Level, x,z: float): float =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return EE.float
  return level.data[i * level.width + j].float

proc mask_at*(level: Level, x,z: float): CliffMask =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return XX
  return level.mask[i * level.width + j]

proc masks_at*(level: Level, x,z: float): set[CliffMask] =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return {}
  return level.map[i,j].masks

proc fixture_at*(level: Level, x,z: float): Fixture =
  let (i,j) = level.xlat_coord(x,z)
  if i < 0 or j < 0 or i >= level.height-1 or j >= level.width-1: return Fixture()
  return level.map[i,j].fixture

proc around*(level: Level, m: CliffMask, x,z: float): bool =
  if level.masks_at(x,z).has m:
    return true
  for i in -1..1:
    for j in -1..1:
      if level.masks_at(x+i.float,z+j.float).has m:
        return true
  return false

proc find_closest*(level: Level, mask: CliffMask, x, z: float): Vec3f =
  var i, j, di, dj, radius: int
  i = -radius ; j = -radius

  while radius < 50:
    if i <= -radius and j == -radius:
      radius.inc ; i = -radius ; j = -radius ; di =  0 ; dj =  1
    elif i == -radius and j >= radius        : di =  1 ; dj =  0
    elif i >= radius and j == radius         : di =  0 ; dj = -1
    elif i == radius and j <= -radius        : di = -1 ; dj =  0

    #echo "i,j = ", $i, ",", $j

    let xi = x + i.float
    let zj = z + j.float
    if level.masks_at(zj, xi).has mask:
      let y = level.data_at(zj, xi)
      result = vec3f( zj, y, xi )
      #echo "FOUND at ", result
      return

    i += di
    j += dj

proc find_s1(data: seq[float], mask: seq[CliffMask], w,h: int): Vec3i =
  for i in 0..<h:
    for j in 0..<w:
      if mask[i*w+j] == S1:
        return Vec3i(arr: [j.int32, data[i*w+j].int32, i.int32])

proc `[]=`*[T:Ordinal](level: Level, i,j: T, mask: CliffMask) =
  let o = level.offset(i,j)
  if o == 0: return
  let cur = level.mask[o]
  level.mask[level.offset(i,j)] = mask
  level.map[i,j].masks.excl cur
  level.map[i,j].masks.excl mask

proc `[]=`*[T:Ordinal](level: Level, i,j: T, value: float) =
  let o = level.offset(i,j)
  if o == 0: return
  level.map[i,j].height = value
  level.data[o] = value

proc index_offset(level: Level, i,j: int): int =
  result = (i-1) * floor_span + (j-7)
  if result < 0: return 0


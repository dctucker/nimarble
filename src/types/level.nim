
type
  Piece* = ref object of RootObj
    case kind*: CliffMask
    of EP:
      firing*: bool
    of RH, RI:
      boost*: float
    else: discard
    origin*: Vec3i
    mesh*: Mesh
  Actor*   = ref object of Piece
    pivot_pos*: Vec3f
    facing*: Vec3f
  Fixture* = ref object of Piece

  CubePoint* = ref object
    pos*: Vec3f
    color*: Vec4f
    normal*: Vec3f
    uv*: Vec3f

  Zone* = ref object
    case kind*: CliffMask
    of EP:
      piston_timing*: seq[int]
    of RH, RI :
      base_floor*: seq[float]
    else: discard
    rect*: Vec4i # e.g. vec4i( left, top, right, bottom )
    clock*: float
    index*: seq[Ind]

  LevelPoint* = object
    height*: float
    masks*: set[CliffMask]
    fixture*: Fixture
    cube*: seq[CubePoint]

  LevelMap* = ref object
    points*: seq[LevelPoint]
    width*: int
    height*: int

  UpdateKind* = enum
    Actors
    Zones
    Fixtures

  ZoneSet* = HashSet[Zone]
  ActorSet* = seq[Actor] # HashSet[Piece]

  LevelUpdate* = ref object
    case kind*: UpdateKind
    of Actors   : actors*   : ActorSet
    of Fixtures : fixtures* : seq[Fixture]
    of Zones    : zones*    : ZoneSet


  Level* = ref object
    width*, height*, span*: int
    origin*        : Vec3i
    clock*         : float
    phase*         : CliffMask
    color*         : Vec3f
    data*          : seq[float]
    mask*          : seq[CliffMask]
    map*           : LevelMap
    floor_colors*  : seq[cfloat]
    floor_index*   : seq[Ind]
    floor_verts*   : seq[cfloat]
    floor_normals* : seq[cfloat]
    floor_uvs*     : seq[cfloat]
    floor_textures*: seq[cfloat]
    floor_plane*   : Mesh
    actors*       : ActorSet
    fixtures*     : seq[Fixture]
    zones*        : ZoneSet
    name*         : string
    updates*      : seq[LevelUpdate]

proc hash*(z: Zone): Hash =
  result = z.kind.hash !& z.rect.hash
  result = !$result

proc hash*(z: Piece): Hash =
  result = z.kind.hash !& z.origin.hash
  result = !$result

proc newLevelMap*(w,h: int): LevelMap =
  return LevelMap(
    points: newSeq[LevelPoint](w*h),
    width: w,
    height: h,
  )

proc `add`*(point: var LevelPoint, mask: CliffMask) =
  point.masks.incl mask

proc cliffs*(mask: CliffMask): CliffMask =
  result = XX
  if mask in CLIFFS:
    return mask

proc cliffs*(masks: set[CliffMask]): CliffMask =
  for cliff in masks * CLIFFS:
    result += cliff

proc cliffs*(point: LevelPoint): CliffMask =
  return point.masks.cliffs()

proc `[]`*[T:Ordinal](map: var LevelMap, i,j: T): var LevelPoint =
  let o = i * map.width + j
  if o < 0 or o >= map.points.len:
    return map.points[0]
  return map.points[o]

proc empty*(p: CubePoint): bool {.inline.} =
  return p.pos.length == 0 and p.color.length == 0 and p.normal.length == 0

proc offset*[T:Ordinal](level: Level, i,j: T): T =
  if j >= level.width  or j < 0: return 0
  if i >= level.height or i < 0: return 0
  result = (level.width * i + j).T


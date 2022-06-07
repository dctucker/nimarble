
proc wave_height*(fixture: Fixture, x: float): float =
  let o = fixture.mesh.elem_vbo.offset + int(x * wave_res) * wave_nverts + 2
  result = fixture.mesh.vert_vbo.data[o * 3 + 1]
  result *= fixture.mesh.scale.y / 0.5

proc ramp_height*(fixture: Fixture): float =
  return fixture.mesh.pos.y

#[
proc wave_height*(level: Level, x,z: float): float =
  let phase = 15f * -x + (level.clock mod 30).float
  const max_height = 3f
  result = max_height * sin(phase.radians)
  result = clamp( result, 0, max_height )
]#

proc floor_height*(level: Level, x,z: float): float =
  let masks = level.masks_at(x,z)
  result = level.data_at(x,z)
  if masks.has SW:
    let (i,j) = level.xlat_coord(x,z)
    result += level.map[i,j].fixture.wave_height(0)
  elif masks.has(RI) or masks.has(RH):
    let (i,j) = level.xlat_coord(x,z)
    result = level.map[i,j].fixture.ramp_height()
  elif masks.has GR:
    result += 1.5f
  elif (masks * {P1,P2,P3,P4}).has level.phase:
    result = 0f

proc slope*(level: Level, x,z: float): Vec3f =
  # this should be refactored to use masks_at
  let m0 = level.mask_at(x+0,z+0)
  let m1 = level.mask_at(x+1,z+0)
  let m2 = level.mask_at(x+0,z+1)
  let p0 = level.floor_height(x+0,z+0)
  let p1 = level.floor_height(x+1,z+0)
  let p2 = level.floor_height(x+0,z+1)
  var dx = p0 - p1
  var dz = p0 - p2

  const pushback = 30
  if (m0 == XX) and (m2.has AA):
    dz = -pushback

  if (m2 == XX) and (m0.has VV):
    dz = +pushback

  if (m0 == XX) and (m1.has LL):
    dx = -pushback

  if (m1 == XX) and (m0.has JJ):
    dx = +pushback

  result = vec3f( dx, 0f, dz )
  if result.length > pushback:
    result = result.normalize() * pushback

proc surface_normal*(level: Level, x,z: float): Vec3f =
  let p0 = level.floor_height(x,z)
  let p1 = level.floor_height(x+1,z)
  let p2 = level.floor_height(x,z+1)
  let u = vec3f(1, p1-p0, 0)
  let v = vec3f(0, p2-p0, 1)
  result = v.cross(u).normalize()

proc point_height*(level: Level, x,z: float): float =
  let h1 = level.floor_height( x+0, z+0 )
  let h2 = level.floor_height( x+1, z+0 )
  let h3 = level.floor_height( x+0, z+1 )
  let h4 = level.floor_height( x+1, z+1 )
  let ux = x - x.floor
  let uz = z - z.floor
  result  = h1 * (1-ux) * (1-uz)
  result += h2 *    ux  * (1-uz)
  result += h3 * (1-ux) *    uz
  result += h4 *    ux  *    uz
  #stdout.write ", floor = ", result.formatFloat(ffDecimal, 3)

proc average_height*(level: Level, x,z: float): float =
  const max_cells = 9
  const max_iters = 81
  var n = 1
  var sum = level.floor_height(x,z)
  proc accum(v: float) =
    if v != EE and v > 0:
      sum += v
      inc n
  var i = 0
  while n < max_cells and i < max_iters:
    inc i
    let ii = i.float
    accum level.floor_height(x+ii, z)
    accum level.floor_height(x-ii, z)
    accum level.floor_height(x  , z+ii)
    accum level.floor_height(x  , z-ii)
    for j in 1..i:
      let jj = j.float
      accum level.floor_height(x+ii, z+jj)
      accum level.floor_height(x-ii, z-jj)
      accum level.floor_height(x-ii, z+jj)
      accum level.floor_height(x+ii, z-jj)
  return sum / n.float


proc apply_phase*(level: var Level, i,j: int) =
  level.calculate_vbos(i,j)

proc queue_update*(level: Level, update: LevelUpdate) =
  level.updates.add update

proc update*[T: HashSet](a: var T, b: T) = a = (a * b) + b

proc update*[T: Piece](a: var seq[T], b: seq[T]) =
  let h1 = a.toHashSet
  let h2 = b.toHashSet
  let h3 = (h1 * h2) + h2
  a = @[]
  for x in h3:
    a.add x

proc apply_update*(level: var Level, update: LevelUpdate) =
  case update.kind
  of Actors   : update level.actors   , update.actors
  of Fixtures : update level.fixtures , update.fixtures
  of Zones    : update level.zones    , update.zones

proc process_updates*(level: var Level) =
  if level.updates.len > 0:
    for update in level.updates:
      level.apply_update(update)
    level.updates = @[]


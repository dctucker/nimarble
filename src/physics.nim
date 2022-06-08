
proc apply_roll_rotation(player: var Player) =
  var mesh = player.mesh
  if (mesh.vel * vec3f(1,0,1)).length > 0:
    var dir = -mesh.vel.normalize()
    var axis = mesh.normal.cross(dir).normalize()
    var angle = mesh.vel.xz.length * dt / 0.5f / Pi / player_radius
    if player.animation == Stun:
      angle *= 0.25f

    let quat = quatf(axis, angle)
    if quat.length > 0:
      mesh.rot = normalize(quat * mesh.rot)

const mass = player_radius
const gravity = -98f
const max_acc = 50f
const max_vel = vec3f( 15f, -gravity * 0.5f, 15f )
const air_brake = 255/256f
const min_air = 1/32f

var cur_masks: set[CliffMask]
var air, last_air: float32
var last_acc: Vec3f

proc no_air =
  last_air = 0
  air = 0

proc apply_air(player: var Player, air: float) =
  var mesh = player.mesh
  if air > min_air:
    mesh.vel.y = clamp(mesh.vel.y + dt * mesh.acc.y, -max_vel.y * 1.5f, max_vel.y)
    last_air = max(last_air, air)
  else:
    mesh.vel.y *= clamp( air / min_air, 0.0, air_brake )

proc detect_impact_damage(player: var Player, air: float) =
  var mesh = player.mesh
  if air > min_air: return
  if last_air < 1f: return
  if last_acc.y.abs < gravity.abs: return

  echo "impact ", mesh.vel.y, " last air ", last_air
  if last_air > 2f: # impact velocity would be >13f
    player.animate Stun, t + 1.5f
  if last_air > 4f: # impact velocity woulde be >26f
    player.animate Break, t + 2f
  last_acc.y *= 0
  no_air()

proc detect_actor_collision(player: var Player, actors: var ActorSet): bool =
  for actor in actors.mitems:
    if (actor.mesh.pos - player.mesh.pos).length < 1f:
      if actor.mesh.scale.length < 1f:
        actor.mesh.scale.y = 0.1f
        continue
      if actor.kind == EA:
        actor.mesh.pos = player.mesh.pos
        player.animate Dissolve, t + 1f
        return true

proc detect_fall_damage(player: var Player) =
  var mesh = player.mesh
  if mesh.pos.y < 10f:
    player.die "fell off"
  if mesh.acc.xz.length == 0f and mesh.vel.y <= -max_vel.y:
    player.die "terminal velocity"

var beats = 0
var traction: float
var ramp, ramp_a: Vec3f
var rail, icy, sandy, oily, copper, stunned, portal: bool

proc get_input_vector(game: Game): Vec3f =
  if game.paused or game.goal or icy or copper:
    return vec3f(0,0,0)
  result = rotate_mouse(mouse)
  if result.length > max_acc:
    result = result.normalize() * max_acc
  if joystick.left_thumb.length > 0.05:
    result += vec3f(joystick.left_thumb.x, -joystick.left_thumb.y, 0).rotate_mouse * 40
  mouse *= 0

proc calculate_acceleration(mesh: var Mesh, input_vector: Vec3f) =
  if mesh.acc.y != 0:
    last_acc = mesh.acc
  mesh.acc *= 0
  mesh.acc += mass * vec3f(input_vector.x, 0, -input_vector.y) * traction
  if not sandy and not oily:
    mesh.acc += vec3f(0, (1f-traction) * gravity, 0)   # free fall

  mesh.acc += ramp_a * traction
  if god(): mesh.acc.y = gravity * 0.125

proc find_closest(game: Game, mask: CliffMask): Vec3f =
  var coord = game.player.coord
  return game.level.find_closest(mask, coord.x, coord.z)

proc maybe_teleport(game: var Game) =
  var player = game.player
  if cur_masks.has(IN) and air < 0.0625f:
    let dest = game.find_closest OU
    if dest.length != 0:
      player.teleport_dest = dest
      player.animate Teleport, t + 1.2f
      no_air()

proc maybe_respawn(game: var Game) =
  var player = game.player
  if player.dead:
    echo "ur ded"
    player.dead = false
    player.animate Respawn, t + 1f
    game.respawns += 1
    no_air()

proc maybe_complete(game: var Game) =
  var mesh = game.player.mesh
  if game.goal:
    mesh.vel *= 0.97f
    if event_time == 0:
      event_time = time
    if time - event_time > 3.0f:
      game.goal = false
      event_time = 0
      next_level.callback(game, true)
  else:
    game.goal = game.goal or cur_masks.has GG

proc update_state(game: var Game) =
  rail    = cur_masks.has GR
  icy     = cur_masks.has IC
  sandy   = cur_masks.has SD
  oily    = cur_masks.has OI
  copper  = cur_masks.has CU
  portal  = (cur_masks * {TU,IN,OU}).card > 0
  stunned = game.player.animation == Stun

  traction = 1.0
  if god():
    air = 0
    last_air = 0
    ramp_a *= 0
  elif air > 0.25: traction *= 0f
  else:
    if sandy   : traction *= 0.5
    if oily    : traction *= 0.75f
    if stunned : traction *= 0.125f


proc physics(game: var Game) =
  var player = game.player
  var mesh = player.mesh
  var level = game.level

  if not game.goal:
    level.tick(t)

  game.physics(level.actors, dt)

  beats.inc
  if beats mod 2 == 0:
    game.physics(level.fixtures, dt)

  if player.animate(t): return

  if not god():
    if player.detect_actor_collision(level.actors): return
    player.detect_fall_damage()

  let x  = player.coord.x
  let z  = player.coord.z

  ramp = level.slope(x,z) * level_squash * level_squash
  let thx = arctan(ramp.x)
  let thz = arctan(ramp.z)
  #let cosx = cos(thx)
  #let cosz = cos(thz)
  let sinx = sin(thx)
  let sinz = sin(thz)

  ramp_a = vec3f( -ramp.x, sinx + sinz, -ramp.z ) * gravity
  if game.level_number == 6: # works for ramps but not walls
    ramp_a = vec3f( ramp.x, sinx + sinz, ramp.z ) * gravity

  cur_masks = level.masks_at(x,z)
  game.update_state()

  if rail:
    let fixture = level.fixture_at(x,z)
    if fixture != nil and fixture.mesh != nil:
      let normal = fixture.normal(player)
      mesh.vel.xz = mesh.vel.reflect(normal).xz

  let bh = mesh.pos.y
  let floor_height = level.point_height(x, z)
  air = bh - floor_height

  let flat = ramp.length == 0
  let nonzero = level.point_height(x.floor, z.floor) > 0f

  let safe = game.safe and
    flat       and
    nonzero    and
    not icy    and
    not copper
  if safe:
    player.respawn_pos = vec3f(mesh.pos.x.floor, mesh.pos.y, mesh.pos.z.floor)

  var m = game.get_input_vector()
  mesh.calculate_acceleration(m)

  let lateral_dir = mesh.vel.xz.normalize()
  let lateral_vel = mesh.vel.xz.length()

  mesh.vel.xz = clamp(mesh.vel.xz + dt * mesh.acc.xz, -max_vel.xz, max_vel.xz)

  player.apply_air(air)
  if not portal:
    player.detect_impact_damage(air)

  if icy:
    if mesh.vel.length * lateral_vel > 0f:
      let dir = normalize(mesh.vel.xz.normalize() + lateral_dir)
      mesh.vel = vec3f(dir.x, 0, dir.y) * lateral_vel
      mesh.vel.y = max_vel.y * -0.5

  mesh.pos += mesh.vel * dt
  mesh.pos.y = clamp(mesh.pos.y, floor_height, sky)

  player.apply_roll_rotation()

  const brake = 0.986
  if not ( icy or copper or oily ):
    mesh.vel *= brake

  if cur_masks.has TU:
    mesh.vel.y = clamp(mesh.vel.y, -max_vel.y, max_vel.y)

  logs.player_vel_y.log mesh.vel.y
  logs.player_acc_y.log mesh.acc.y
  logs.air.log air

  if god(): return # a god neither dies nor achieves goals

  game.maybe_teleport()
  game.maybe_respawn()
  game.maybe_complete()


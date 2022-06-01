import std/random
import std/sets
import glm
import leveldata
import masks
import types
import scene

proc `$`*(a: Actor): string =
  return $(a.kind) & " " & $(a.origin)

proc `~=`*(a1, a2: Actor): bool =
  return a1.kind == a2.kind and a1.origin == a2.origin

proc tick_pistons*(level: Level, zone: Zone, t: float) =
  let piston_times = zone.piston_timing
  zone.clock = t * 0.375
  let cur_time = (zone.clock * 100).floor.int mod 100
  if cur_time notin piston_times: return

  for n,i,j in level.indexed_coords(zone):
    if piston_times[n mod piston_times.len] != cur_time: continue
    for actor in level.actors:
      if actor.kind != EP: continue
      if actor.origin.x != j or actor.origin.z != i: continue
      actor.firing = true

proc tick_phase_zones*(level: var Level) =
  let phase = CliffMask(P1.ord + (level.clock.floor.int mod 4))

  if level.phase == phase: return

  let previous = level.phase
  level.phase = phase

  for zone in level.zones:
    if zone.kind == previous:
      level.phase_in_index(zone)

  level.process_updates()

  for zone in level.zones:
    if zone.kind == level.phase:
      level.phase_out_index(zone)

  level.update_index_vbo() # TODO update subset only for performance

proc tick_ramp(level: Level, zone: Zone, t: float) =
  zone.clock = fract(t * 0.25)
  for n,i,j in level.indexed_coords(zone):
    let point = level.map[i,j]
    if point.fixture.mesh == nil: continue # TODO for editing
    if zone.clock < 0.5:
      point.fixture.mesh.pos.y = point.height + (zone.clock) * 3
    else:
      point.fixture.mesh.pos.y = point.height + (3 - (zone.clock * 3))

proc tick*(level: var Level, t: float) =
  level.clock = t
  level.tick_phase_zones()
  for zone in level.zones:
    case zone.kind
    of EP:
      level.tick_pistons(zone, t)
    of RH, RI:
      level.tick_ramp(zone, t)
    else:
      discard

const directions = @[
  vec3f( -1,  0,  0 ),
  vec3f( +1,  0,  0 ),
  vec3f(  0,  0, -1 ),
  vec3f(  0,  0, +1 ),
]
proc random_direction: Vec3f = return directions[rand(directions.low..directions.high)]

proc meander(game: Game, actor: var Actor, dt: float) =
  if actor.facing.length == 0:
    actor.facing = random_direction()
  if (actor.pivot_pos - actor.mesh.pos).length >= 1f:
    actor.pivot_pos = actor.mesh.pos
    actor.facing = random_direction()
  let next_pos = actor.mesh.pos + actor.facing * dt
  if game.level.slope(next_pos.x, next_pos.z).length == 0:
    actor.mesh.pos = next_pos
  else:
    actor.facing = random_direction()

proc slink(game: Game, actor: var Actor, dt: float) =
  game.meander(actor, dt)
  # TODO apply slink animation

proc roll(game: Game, actor: var Actor, dt: float) =
  var rot = mat4f(1)
  rot = rot.rotate(180f.radians * dt, vec3f(0,1,0))
  actor.facing = (rot * vec4f(actor.facing, 1.0)).xyz.normalize()
  actor.mesh.acc = actor.facing * 2f
  #actor.mesh.vel = clamp( actor.mesh.vel + actor.mesh.acc * dt, -1f, 1f )
  actor.mesh.vel += actor.mesh.acc * dt
  actor.mesh.pos += actor.mesh.vel * dt

proc stalk(game: Game, actor: var Actor, dt: float) =
  # TODO chase the player
  discard

proc animate_piston(game: Game, actor: var Actor, dt: float) =
  const max_y = 2f
  let dy = 12f * dt
  if actor.mesh.translate.y >= max_y:
    actor.firing = false

  if actor.firing:
    actor.mesh.translate.y += dy
  else:
    if actor.mesh.translate.y > 0:
      actor.mesh.translate.y -= dy
      if actor.mesh.translate.y < 0:
        actor.mesh.translate.y = 0


#[
x ~= -offset

               __               |
             /    \             |
           /        \           |
         /            \         |
________/              \________|
0123456789abcdef0123456789abcdef| offset = 0

                __              |
              /    \            |
            /        \          |
          /            \        |
_________/              \_______|
f0123456789abcdef0123456789abcde| offset = 31

    xm = (piece.origin.x mod wave_len).float
    offset = cint xm * wave_ninds * wave_res
    result.pos.x = -xm

    offset = (piece.origin.x mod wave_len) * wave_ninds * wave_res
    (piece.origin.x mod wave_len) = offset / (wave_ninds * wave_res)
]#
import models
proc animate_wave(game: Game, piece: var Fixture, dt: float) =
  let max_offset = cint wave_res * wave_ninds * wave_len

  var offset = piece.mesh.elem_vbo.offset - wave_ninds
  if offset > max_offset : offset -= max_offset
  if offset < 0          : offset += max_offset

  piece.mesh.elem_vbo.offset = offset
  #piece.mesh.pos.x =  - (offset / (wave_ninds * wave_res)).float

  let xm = (piece.origin.x mod wave_len).float
  piece.mesh.translate.x += 1f/wave_res
  if piece.mesh.translate.x > 0f:
    piece.mesh.translate.x -= wave_len

proc reaction(e: CliffMask): Animation =
  case e
  of EA: Dissolve
  of EM: Shove
  of EV: Consume
  of EP: Launch
  of EH: Shove
  of EB: Explode
  of EY: Consume
  else: None

proc reflect*(v1, normal: Vec3f): Vec3f =
  result = v1 - 2 * v1.dot(normal) * normal

proc normal*(fixture: Fixture, player: Player): Vec3f =
  let diff = fixture.mesh.pos - player.mesh.pos
  if diff.x.abs > diff.z.abs:
    result.x = diff.x
  else:
    result.z = diff.z

proc physics*(game: Game, actor: var Actor, dt: float) =
  case actor.kind
  of EA:
    if game.player.animation == Dissolve: return
    if actor.mesh.scale.y < 0.125f: return
    game.meander(actor, dt)
  of EM:
    if actor.mesh.scale.y < 0.125f: return
    game.roll(actor, dt)
    if (actor.mesh.pos - game.player.mesh.pos).length < 3f:
      game.stalk(actor, dt)
  of EY:
    if actor.mesh.scale.y < 0.125f: return
    game.slink(actor, dt)
  of EP:
    game.animate_piston(actor, dt)
  else:
    discard

proc physics*(game: Game, fixture: var Fixture, dt: float) =
  case fixture.kind
  of SW:
    game.animate_wave(fixture, dt)
  else:
    discard


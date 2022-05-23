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

#[
1   2   3   4
5   6   7   8
9   10  11  12

1 11 8  5 2 12
 3 6 9  4 7 10
]#

#[ TODO store this as 2D vector (frequency, offset)
  - frequency would be aligned for the less complex patterns with only offset differing each piston
  - offset would vary for more complex polyrhythmic patterns
]#
const piston_time_variations = @[
  @[
    10, 30, 30, 10,
    10, 30, 30, 10,
    10, 30, 30, 10,
  ],
  @[
    35, 45, 60, 75,
    60, 75, 10, 45,
    10, 20, 35, 20,
  ],
  @[
    10, 35, 60, 85,
    35, 60, 85, 10,
    60, 85, 10, 35,
  ],
  @[
    85, 60,35, 10,
    85, 60,35, 10,
    85, 60,35, 10,
  ],
  @[
    40, 10, 40, 10,
    40, 10, 40, 10,
    40, 10, 40, 10,
  ],
]
const piston_times = piston_time_variations[^1]

proc tick_pistons*(level: Level, zone: Zone, t: float) =
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


proc tick*(level: var Level, t: float) =
  level.clock = t
  level.tick_phase_zones()
  for zone in level.zones:
    if zone.kind != EP: continue
    level.tick_pistons(zone, t)

const directions = @[
  vec3f( -1,  0,  0 ),
  vec3f( +1,  0,  0 ),
  vec3f(  0,  0, -1 ),
  vec3f(  0,  0, +1 ),
]
proc random_direction: Vec3f = return directions[rand(directions.low..directions.high)]

proc meander*(game: Game, actor: var Actor, dt: float) =
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

proc animate_piston(game: Game, actor: var Actor, dt: float) =
  const max_y = 4f
  let dy = 18f * dt
  if actor.mesh.scale.y >= max_y:
    actor.firing = false

  if actor.firing:
    actor.mesh.scale.y += dy
  else:
    if actor.mesh.scale.y > 0:
      actor.mesh.scale.y -= dy
      if actor.mesh.scale.y < 0:
        actor.mesh.scale.y = 0


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
  piece.mesh.pos.x += 0.125
  #if (24f + piece.mesh.pos.x).int mod 12 == 8:
  #  piece.mesh.pos.x = -4f
  #  let xm = (piece.origin.x mod wave_len).float

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

proc physics*(game: Game, actor: var Actor, dt: float) =
  case actor.kind
  of EA:
    if game.player.animation == Dissolve: return
    game.meander(actor, dt)
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


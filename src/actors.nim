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

const piston_sequences = @[
  @[
    @[0,4,8],
    @[],
    @[1,5,9],
    @[],
    @[2,6,10],
    @[],
    @[3,7,11],
    @[],
    @[],
  ],
  @[
    @[2,5,8],
    @[],
    @[3,6,9],
    @[],
    @[0,10,7],
    @[],
    @[4,1,11],
    @[],
    @[],
  ],
  @[
    @[0,4],
    @[],
    @[5,9],
    @[],
    @[2,6],
    @[],
    @[7,11],
    @[],
    @[],
  ],
  @[
    @[8,6],
    @[],
    @[9,11],
    @[],
    @[0,10],
    @[],
    @[1,7],
    @[],
    @[4,2],
    @[],
    @[5,3],
    @[],
    @[],
  ],
  @[
    @[1,5,9,2,6,10],
    @[],
    @[0,4,8,3,7,11],
    @[],
    @[],
    @[],
  ],
  # etc...
  # TODO possibly rewrite to indicate firing phase of each piston instead of piston sequence per phase
]

proc tick_pistons*(level: Level, zone: Zone, t: float) =
  zone.clock = t * 3

  const sequence = piston_sequences[^1]
  let firing = zone.clock.int mod sequence.len

  if zone.clock - zone.clock.int.float < 0.1:
    for n,i,j in level.indexed_coords(zone):
      if n notin sequence[firing]: continue
      let n = (i - zone.rect.y) * (zone.rect.z - zone.rect.x) + (j - zone.rect.x)
      for actor in level.actors:
        if actor.kind != EP: continue
        if actor.origin.x != j or actor.origin.z != i: continue
        actor.firing = true
  else:
    discard


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


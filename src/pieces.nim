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

include pieces/[
  acid   ,
  marble ,
  phase  ,
  piston ,
  ramp   ,
  wave   ,
  yum    ,
]

proc tick*(level: var Level, t: float) =
  level.clock = t
  level.tick_phase_zones()
  for zone in level.zones:
    case zone.kind
    of EP    : level.tick_pistons(zone, t)
    of RH, RI: level.tick_ramp(zone, t)
    else: discard

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


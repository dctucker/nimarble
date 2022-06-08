
proc hazard(actor: Actor): bool =
  return actor.kind.hazard

proc safe*(game: Game): bool =
  const distance = 5f
  let player_pos = game.player.mesh.pos
  for actor in game.level.actors:
    if not actor.hazard: continue
    if (actor.mesh.pos - player_pos).length < distance:
      return false
  return true

proc die*(player: var Player, why: string) =
  if not player.dead:
    echo why
  player.dead = true

proc next*(ani: Animation): Animation =
  result = case ani
    of Dissolve,
       Explode,
       Break,
       Consume   : Respawn
    else: Animation.None

proc animate*(player: var Player, ani: Animation, t: float) =
  player.animation_time = t
  player.animation = ani
  echo player.animation

proc animate*(player: var Player, t: float): bool =
  if player.animation == Animation.None:
    return false
  if player.animation_time <= 0:
    return false
  if t >= player.animation_time:
    player.animation_time = 0f
    player.animation = player.animation.next

  case player.animation
  of Teleport:
    player.mesh.vel *= 0
    player.mesh.acc *= 0
    player.mesh.pos = player.teleport_dest
    player.respawn_pos = player.teleport_dest
  of Dissolve:
    player.die("dissolving")
    player.mesh.pos.y -= 0.03125f
  of Respawn:
    player.mesh.vel *= 0
    player.mesh.acc *= 0
    player.mesh.scale = vec3f(1,1,1)
    player.mesh.pos = player.respawn_pos
  of Break:
    if player.mesh.scale.y < 0.5f:
      player.mesh.scale *= 255/256f
    else:
      player.mesh.scale *= vec3f(513/512f, 127/128f, 513/512f)
      player.mesh.scale = clamp( player.mesh.scale, 0.1, 1.5 )
  of Stun:
    const peak = 1.375
    let left = player.animation_time - t
    var spin: float32
    if left > peak:
      spin = 1f - ((left - peak) / (1.5 - peak))
    else:
      spin = left / peak
    #echo spin
    player.mesh.rot = player.mesh.rot.rotate(20f.radians * spin, vec3f(0,1,0))
    return false
  else:
    discard

  return true


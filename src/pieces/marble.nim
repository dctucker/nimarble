
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



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


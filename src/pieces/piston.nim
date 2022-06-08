
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


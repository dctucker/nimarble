
#proc find_actors(data: seq[float], mask: seq[CliffMask], w,h: int): ActorSet
#  for i in 0..<h:
#    for j in 0..<w:
#      let o = i * w + j
#      let mask = mask[o]
#      if mask in {EY, EM, EA, EV, EP, EH}:
#        result.add Actor(
#          origin: vec3i( j.int32, data[o].int32, i.int32 ),
#          kind: mask,
#        )
#
#proc find_actors*(level: var Level) =
#  proc has_actor(level: Level, actor: Actor): bool =
#    result = false
#    for ac in level.actors:
#      if ac ~= actor:
#        return true
#  for actor in find_actors(level.data, level.mask, level.width, level.height):
#    if not level.has_actor(actor):
#      level.actors.add actor

## TODO refactor this to use HashSet
proc find_actors*(level: var Level): ActorSet =
  for i,j in level.coords:
    let height = level.map[i,j].height
    for mask in level.map[i,j].masks:
      if mask in {EY, EM, EA, EV, EP, EH}:
        result.add Actor(
          origin: vec3i( j.int32, height.int32, i.int32 ),
          kind: mask,
        )


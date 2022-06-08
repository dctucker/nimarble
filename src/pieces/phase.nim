
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


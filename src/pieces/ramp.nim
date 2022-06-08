
proc ramp_phase(clock: float): float =
  if   clock < 0.125: result = 0
  elif clock < 0.375: result = (clock - 0.125) / 0.25
  elif clock < 0.625: result = 1
  elif clock < 0.875: result = 1 - (clock - 0.625) / 0.25
  else              : result = 0

proc tick_ramp(level: Level, zone: Zone, t: float) =
  zone.clock = fract(t * 0.25) # [0..1]
  for n,i,j in level.indexed_coords(zone):
    let point = level.map[i,j]
    var fixture = point.fixture
    if fixture.mesh == nil: continue # TODO for editing
    var mesh = fixture.mesh
    var height = point.height
    let phase = zone.clock.ramp_phase()

    # TODO this calculation is messy an inaccurate
    let next_height = level.map[i,j+1].height
    #let base_height = point.height * fixture.boost
    height *= 1 + (fixture.boost - 1) * phase
    #let at = arctan(0.5 * (height - base_height))
    mesh.pos.y = height

    let rotz = (1 - phase) * arctan(point.height - next_height)
    mesh.rot = quatf(0,0,0,1).rotate( rotz * 0.5, vec3f(0,0,-1))
    #mesh.translate.x = sin(at * 0.5)


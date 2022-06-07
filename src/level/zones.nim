
proc find_fixtures*(level: var Level): seq[Fixture] =
  for i,j in level.coords:
    for mask in level.map[i,j].masks:
      let height = level.map[i,j].height
      if mask.fixture():
        let fix = Fixture(
          origin: vec3i( j.int32, height.int32, i.int32 ),
          kind: mask,
        )
        result.add fix
        level.map[i,j].fixture = fix

  for zone in level.zones:
    let (i0,j0) = level.xlat_coord(zone.rect.x, zone.rect.y)
    var edge_height: float
    case zone.kind
    of RH: edge_height = level.map[i0, j0 - 1].height
    of RI: edge_height = level.map[i0 - 1, j0].height
    else: continue
    for n,i,j in level.indexed_coords(zone):
      let height = level.map[i,j].height
      var fix = level.map[i,j].fixture
      if fix.kind notin {RH, RI}: continue
      fix.boost = edge_height / height
      echo edge_height, " / ", height, " = ", fix.boost

iterator by_axis(d: int): Vec2i =
  proc cmp(v1, v2: Vec3i): int = cmp(v1.y, v2.y)
  var points = newSeqOfCap[Vec3i](2*d)
  for n in 1 .. d:
    points.add vec3i( n.int32, n.int32, 0       )
    points.add vec3i( 0,       n.int32, n.int32 )
  points.sort(cmp)
  for point in points:
    yield vec2i(point.x, point.z)

iterator by_area(w,h: int): Vec2i =
  proc cmp(v1, v2: Vec3i): int = cmp(v1.y, v2.y)
  var points = newSeqOfCap[Vec3i](w*h)
  for i in 0 ..< h:
    for j in 0 ..< w:
      var area = vec2f(1f+i.float, 1f+j.float).length
      points.add vec3i( j.int32, area.int32, i.int32 )
  points.sort(cmp)
  for point in points:
    yield vec2i(point.x, point.z)

proc find_zones*(level: Level, masks: set[CliffMask]): ZoneSet =
  var consumed: seq[Vec2i] = @[]
  var criteria: CliffMask
  var first: Vec2i

  proc is_consumed(x,z: int32): bool =
    return vec2i(x, z) in consumed

  proc search_axes(sx,sz: int): Vec2i =
    for point in by_axis(5):
      result = vec2i( int32 sx + point.x, int32 sz + point.y )
      # singular mask detection to identify points within source data
      let mask = level.mask_at( result.x.float, result.y.float )
      if mask == criteria:
        return

    result = vec2i(0,0)

  proc search_forward(sx,sz: int): Vec2i =
    for point in by_area(24,24):
      result = vec2i( int32 sx + 1 + point.x, int32 sz + 1 + point.y )
      # singular mask detection to identify points within source data
      let mask = level.mask_at( result.x.float, result.y.float )
      if mask == criteria:
        return
    result = vec2i(0,0)

  for x in -level.origin.x ..< level.width - level.origin.x:
    for z in -level.origin.z ..< level.height - level.origin.z:
      if is_consumed(x.int32, z.int32): continue
      criteria = level.mask_at(x.float, z.float)
      if not (criteria in masks): continue

      # found start phase block
      first = vec2i(x.int32, z.int32)

      var last: Vec2i
      var zone: Zone

      if criteria in {GR}: # linear
        last = search_axes(x.int, z.int)
        if last.x == 0 and last.y == 0: continue

        # found end point
        zone = Zone(
          rect: vec4i( first.x, first.y, last.x, last.y ),
          kind: criteria,
        )

      else: # rectangular
        last = search_forward(x.int, z.int)
        if last.x == 0 and last.y == 0: continue

        # found end corner
        zone = Zone(
          rect: vec4i( first.x, first.y, last.x - 1, last.y - 1 ),
          kind: criteria,
        )

      case zone.kind
      of EP:
        zone.piston_timing = piston_time_variations[^1]
      else: discard
      result.incl zone

      consumed.add first
      consumed.add last

proc find_zones*(level: Level): ZoneSet =
  result.incl level.find_zones zone_masks


proc phase_out_index*(level: Level, zone: Zone) =
  for i,j in level.coords(zone):
    for n in cube_index.low .. cube_index.high:
      let o = level.index_offset(i,j) * cube_index.len + n
      level.floor_index[o] = 0

proc phase_in_index*(level: Level, zone: Zone) =
  for i,j in level.coords(zone):
    for n in cube_index.low .. cube_index.high:
      let o = level.index_offset(i,j) * cube_index.len + n
      level.floor_index[o] = o.Ind


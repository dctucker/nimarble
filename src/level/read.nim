proc flatten[T](input: seq[seq[T]]): seq[T] =
  for row in input:
    for value in row:
      result.add value

proc tsv_floats(line: string): seq[float] =
  result = line.split("\t").map(proc(s:string):float =
    if s.len() > 0: s.parseFloat
    else: 0
  )
  #echo result.len

proc is_numeric(s: string): bool =
  try:
    discard s.parseFloat()
    result = true
  except:
    result = false

proc parse_mask(s: string): CliffMask =
  try:
    result = parseEnum[CliffMask](s)
  except:
    if s.len > 0 and s != "0":
      if not s.is_numeric():
        echo "Unrecognized mask: " & s
    result = CliffMask.XX

proc tsv_masks(line: string): seq[CliffMask] =
  var j = 0
  result = line.split("\t").map(proc(s:string):CliffMask =
    j += 1
    result = parse_mask(s)
  )

proc validate(level: Level): bool =
  let size = level.width * level.height
  if (size > level.data.len) or (size > level.mask.len):
    echo "Level height:" & $level.height & " width:" & $level.width & " size:" & $size & " do not match data length (" & $level.data.len & ") or mask length (" & $level.mask.len & ")"
    return false
  let w = level.width
  for i in 0..<level.height:
    for j in 0..<w:
      proc unsloped(mask: CliffMask) =
        echo $mask & " without slope at ", cell_name(i, j)
      let data = level.data[i*w+j]
      let mask = level.mask[i*w+j]
      if mask == LL:
        if level.data[i*w+j-1] == data:
          mask.unsloped()
      if mask == AA:
        if level.data[(i-1)*w+j] == data:
          mask.unsloped()
      if mask == VV:
        if level.data[(i+1)*w+j] == data:
          mask.unsloped()
      if mask == JJ:
        if level.data[i*w+j+1] == data:
          mask.unsloped()

proc find_span(level: Level): int =
  for j in 0..<level.width:
    for i in 0..<level.height:
      if level.data[ level.offset(i,j) ] != 0:
        result = max(result, j - i)

proc find_first*(level: Level): (int,int) =
  var ii, jj: int
  for i in 0..<level.height:
    for j in 0..<level.width:
      if level.data[i*level.width + j] != 0:
        ii = i
        break
    if ii > 0: break
  for j in 0..<level.width:
    for i in 0..<level.height:
      if level.data[i*level.width + j] != 0:
        jj = j
    if jj > 0: break
  echo "first = ", ii, ",", jj
  return (ii,jj)

proc find_last*(level: Level): (int,int) =
  var ii, jj: int
  for i in countdown(level.height - 1, 0):
    for j in countdown(level.width - 1, 0):
      if level.data[i*level.width + j] != 0:
        ii = i
    if ii > 0: break
  for j in countdown(level.width - 1, 0):
    for i in countdown(level.height - 1, 0):
      if level.data[i*level.width + j] != 0:
        jj = j
    if jj > 0: break
  echo "last = ", ii, ",", jj
  return (ii,jj)

proc load_masks*(level: var Level, zones: ZoneSet, i,j: int) =
  level.map[i,j].masks = {}
  let o = i*level.width + j
  if (0 > o) or (o > level.mask.len): return
  let mask = level.mask[o]
  if mask != XX:
    if not mask.zone():
      level.map[i,j].add mask
  for zone in zones:
    for ii,jj in level.coords(zone):
      if i == ii and j == jj:
        level.map[i,j].masks.incl zone.kind

proc init_map(level: var Level) =
  for i in 0 ..< level.height:
    for j in 0 ..< level.width:
      let o = i*level.width + j
      let mask = level.mask[o]
      if mask != XX:
        if not mask.zone():
          level.map[i,j].add mask
      level.map[i,j].height = level.data[o]
  for zone in level.zones:
    for i in zone.rect.y .. zone.rect.w:
      for j in zone.rect.x .. zone.rect.z:
        level.map[i + level.origin.z, j + level.origin.x].masks.incl zone.kind

proc init_level(name, data_src, mask_src: string, color: Vec3f): Level =
  let source_lines = data_src.splitLines().filter(proc(line:string): bool = return line.len > 0)
  let data = source_lines.map(tsv_floats).flatten()
  let mask = mask_src.splitLines.map(tsv_masks).flatten()
  let height = source_lines.len()
  let width = source_lines[0].split("\t").len()
  result = Level(
    name: name,
    height: height,
    width: width,
    data: data,
    mask: mask,
    color: color,
    map: newLevelMap(width, height),
  )
  #discard result.validate()
  result.origin   = find_s1(data, mask, width, height)
  result.span     = result.find_span()
  result.zones    = result.find_zones()
  result.init_map()
  result.actors   = result.find_actors()
  result.fixtures = result.find_fixtures()
  echo "Level ", result.width, "x", result.height, " span=", result.span, ", ", result.actors.len, " actors"


proc parseMask*(level: Level, str: string): CliffMask =
  return parse_mask(str)

proc parseFloat*(level: Level, str: string): float =
  try:
    return str.parseFloat()
  except:
    return 0f


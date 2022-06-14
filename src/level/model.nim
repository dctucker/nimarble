
proc add_uv(uvs: var seq[cfloat], uv: Vec2f) =
  uvs.add uv.x
  uvs.add uv.y

proc add_uv(uvs: var seq[cfloat], uv: Vec3f) =
  uvs.add uv.x
  uvs.add uv.y
  uvs.add uv.z

proc add_normal(normals: var seq[cfloat], n: Vec3f) =
  let nn = n.normalize()
  normals.add nn.x
  normals.add nn.y
  normals.add nn.z

proc add_color(colors: var seq[cfloat], c: Vec4f) =
  colors.add c.x
  colors.add c.y
  colors.add c.z
  colors.add c.w

proc cube_point*(level: Level, i,j, w: int): CubePoint =
  const margin = 2047/2048f
  let vert = cube_verts[ cube_index[w] ]

  #let m0 = level.map[i+0, j+0].cliffs
  let m1 = level.map[i+0, j+1].cliffs
  let m2 = level.map[i+1, j+0].cliffs
  let m3 = level.map[i+1, j+1].cliffs

  var y0 = level.map[i+0, j+0].height + vert.y.float * (1-margin)
  var y1 = level.map[i+0, j+1].height + vert.y.float * (1-margin)
  var y2 = level.map[i+1, j+0].height + vert.y.float * (1-margin)
  var y3 = level.map[i+1, j+1].height + vert.y.float * (1-margin)
  var yc: float = 0

  let masks = level.map[i,j].masks

  if masks.has level.phase:
    y0 = 0 ; y1 = 0 ; y2 = 0 ; y3 = 0

  var x = (j - level.origin.x).float + vert.x.float * margin
  var z = (i - level.origin.z).float + vert.z.float * margin
  var y = level.data[level.offset(i+vert.z.int, j+vert.x.int)] + vert.y.float * (1-margin)
  var c = level.point_color(i, j)
  var m = level.mask[level.offset(i+vert.z.int, j+vert.x.int)]

  var tile: int
  var color_w = cube_colors[w]

  var base: float = -2

  if RH in masks:
    y = 0 ; y0 = 0 ; y1 = 0 ; y2 = 0 ; y3 = 0

  if y0 != 0 and y3 != 0 and (
    FL in masks or
    RH in masks or
    RI in masks
  ):
    if y != 0:
      base = y - 1.5
    else:
      base = y0 - 1.5

  if vert.y == 0:
    y = base + margin * vert.y
    #c = vec4f(0,0,0,0)
  else:
    if m.has JJ:
      y0 = y1
      y2 = y3
    if m.has VV:
      y0 = y2
      y1 = y3
    if m1.has LL:
      y1 = y0
    if m3.has LL:
      y1 = y0
      y3 = y2
    if m2.has AA:
      y2 = y0
      y3 = y1
    if m3.has AA:
      y3 = y1
    if m1.has(VV) and m2.has JJ:
      y0 = y3

    #if y0 == 0 or y1 == 0 or y2 == 0 or y3 == 0:
    #  y0 = base ; y1 = base ; y2 = base ; y3 = base

    const too_high = 5
    if   (y0 - y1) >= too_high: y0 = y1
    elif (y1 - y0) >= too_high: y1 = y0
    if   (y0 - y2) >= too_high: y0 = y2
    elif (y2 - y0) >= too_high: y2 = y0
    if   (y2 - y3) >= too_high: y2 = y3
    elif (y3 - y2) >= too_high: y3 = y2
    if   (y1 - y3) >= too_high: y1 = y3
    elif (y3 - y1) >= too_high: y3 = y1

    if not level.map[i+0,j+0].masks.has(RH) and level.map[i+0,j+1].masks.has RH:
      y1 = y0
      y3 = y2

    if (y0 == y2 and y1 == y3) or
       (y0 == y1 and y2 == y3)               : yc = (y0 + y3) * 0.5
    elif y0 == y1 and y1 == y2 and y2 != y3  : yc = y0
    elif y1 == y2 and y2 == y3 and y3 != y0  : yc = y3
    elif y0 == y3                            : yc = y0
    elif y1 == y2                            : yc = (y0 + y3) * 0.5
    else                                     : yc = (y0 + y1 + y2 + y3) / 4f

    if   vert.z == 0 and vert.x == 0: y = y0
    elif vert.z == 0 and vert.x == 1: y = y1
    elif vert.z == 1 and vert.x == 0: y = y2
    elif vert.z == 1 and vert.x == 1: y = y3
    elif vert.z==0.5 and vert.x==0.5: y = yc

  result = CubePoint()
  # hide tiles on the ground
  if level.map[i+0,j+0].height == 0 or
     level.map[i+1,j+0].height == 0 or
     level.map[i+0,j+1].height == 0 or
     level.map[i+1,j+1].height == 0:
    return

  if RH in masks or RI in masks:
    c = level.mask_color({RI})

  if color_w != 1:
    result.normal = cube_normal(color_w)

  if result.normal.y.classify == fcNaN:
    result.normal = vec3f(0, 1, 0)

  tile = level.point_texture(i, j) + 1
  result.uv = vec3f(x, z, tile.cfloat)

  #c = case color_w
  #of 2, 4: level.cliff_color(JJ)
  #of 3, 5: level.cliff_color(VV)
  #else   : c

  if color_w in {2,4,3,5}:
    tile = CliffMask.high.ord + 2
    c = default_color
    if color_w in {2,4}:
      result.uv.x = z
    result.uv.y = y
    result.uv.z = tile.cfloat

  result.color = c
  result.pos = vec3f(x, y, z)

proc update_vbos*(level: Level) {.inline.} =
  # TODO update subset only for performance
  level.floor_plane.vert_vbo.update
  level.floor_plane.color_vbo.update
  level.floor_plane.norm_vbo.update
  level.floor_plane.uv_vbo.update

proc update_vert_vbo*(level: Level) {.inline.} =
  level.floor_plane.vert_vbo.update

proc update_normal_vbo*(level: Level) {.inline.} =
  level.floor_plane.norm_vbo.update

proc update_color_vbo*(level: Level) {.inline.} =
  level.floor_plane.color_vbo.update

proc update_index_vbo*(level: Level) {.inline.} =
  level.floor_plane.elem_vbo.update

proc update_uv_vbo*(level: Level) {.inline.} =
  level.floor_plane.elem_vbo.update

proc calculate_color_vbo*(level: Level, i,j: int) =
  let color_span  = 4 * cube_index.len
  if not level.has_coord(i,j): return

  let o = level.index_offset(i,j) # (i-1) * floor_span + (j-7)
  if o <= 0: return
  for n in cube_index.low .. cube_index.high:
    let p = level.cube_point(i, j, n)
    #if p.empty: continue

    let color_offset = o *  color_span + 4*n
    if 0 < color_offset and color_offset < level.floor_colors.len:
      level.floor_colors[  color_offset + 0 ] = p.color.x
      level.floor_colors[  color_offset + 1 ] = p.color.y
      level.floor_colors[  color_offset + 2 ] = p.color.z
      level.floor_colors[  color_offset + 3 ] = p.color.w

proc calculate_top_normals*(level: var Level, i, j: int) =
  const tops = top_points.sorted()
  for s in 0..3:
    let m = tops[s * 3]
    var p0 = level.map[i,j].cube[m+0]
    var p1 = level.map[i,j].cube[m+1]
    var p2 = level.map[i,j].cube[m+2]
    let normal = (p1.pos - p0.pos).cross(p2.pos - p1.pos).normalize()
    p0.normal = normal
    p1.normal = normal
    p2.normal = normal

proc calculate_vbos*(level: var Level, i, j, n: int, p: CubePoint) =
  const color_span  = 4 * cube_index.len
  const normal_span = 3 * cube_index.len
  const vert_span   = 3 * cube_index.len
  const uv_span     = 3 * cube_index.len

  let o = level.index_offset(i,j)
  let vert_offset = o *   vert_span + 3*n + 1
  if vert_offset >= level.floor_verts.len:
    return
  level.floor_verts[   vert_offset               ] = p.pos.y
  #if n in middle_points:
  #  for m in middle_points:
  let v_offset = o *   vert_span + 3*n
  level.floor_verts[   v_offset + 0           ] = p.pos.x
  level.floor_verts[   v_offset + 1           ] = p.pos.y
  level.floor_verts[   v_offset + 2           ] = p.pos.z

  let color_offset = o *  color_span + 4*n
  if 0 < color_offset and color_offset < level.floor_colors.len:
    level.floor_colors[  color_offset + 0 ] = p.color.x
    level.floor_colors[  color_offset + 1 ] = p.color.y
    level.floor_colors[  color_offset + 2 ] = p.color.z
    level.floor_colors[  color_offset + 3 ] = p.color.w

  let normal_offset = o * normal_span + 3*n
  if 0 < normal_offset and normal_offset < level.floor_normals.len:
    level.floor_normals[ normal_offset + 0 ] = p.normal.x
    level.floor_normals[ normal_offset + 1 ] = p.normal.y
    level.floor_normals[ normal_offset + 2 ] = p.normal.z

  let uv_offset = o * uv_span + 3*n
  if 0 < uv_offset and uv_offset < level.floor_uvs.len:
    level.floor_uvs[ uv_offset + 0 ] = p.uv.x
    level.floor_uvs[ uv_offset + 1 ] = p.uv.y
    level.floor_uvs[ uv_offset + 2 ] = p.uv.z

proc calculate_vbos*(level: var Level, i,j: int) =
  if not level.has_coord(i,j): return

  let o = level.index_offset(i,j) # (i-1) * floor_span + (j-7)
  if o <= 0: return

  for n in cube_index.low .. cube_index.high:
    let p = level.cube_point(i, j, n)
    if level.map[i,j].cube.len == 0:
      level.map[i,j].cube = newSeq[CubePoint](cube_index.len)
    level.map[i,j].cube[n] = p

  level.calculate_top_normals(i,j)

  for n in cube_index.low .. cube_index.high:
    let p = level.map[i,j].cube[n]
    #if p.empty: continue
    level.calculate_vbos(i,j,n, p)

proc reload_colors*(level: var Level) =
  for i,j in level.coords:
    level.calculate_color_vbo(i,j)
  level.update_color_vbo()


proc setup_floor(level: var Level) =
  let dim = level.height * level.width
  #var cx: Vec4f
  var normals = newSeqOfCap[cfloat]( dim )
  #var lookup  = newTable[(cfloat,cfloat,cfloat), Ind]()
  var verts   = newSeqOfCap[cfloat]( 3 * dim )
  var index   = newSeqOfCap[Ind]( cube_index.len * dim )
  var colors  = newSeqOfCap[cfloat]( 4 * cube_index.len * dim )
  var uvs     = newSeqOfCap[cfloat]( 3 * cube_index.len * dim )
  var n = 0.Ind
  var x,z: float
  var y: float      #var y0, y1, y2, y3: float
  #var m: CliffMask  #var m0, m1, m2, m3: CliffMask
  #var c: Vec4f      #var c0, c1, c2, c3: Vec4f
  #var v00, v01, v02, v03: Vec3f
  #var v10, v11, v12, v13: Vec3f
  #var v20, v21, v22, v23: Vec3f
  #var v30, v31, v32, v33: Vec3f
  #var surface_normal: Vec3f
  #var normal: Vec3f

  proc add_index =
    index.add n
    inc n

  #proc add_index(nn: Ind) =
  #  index.add nn

  proc add_point(x,y,z: cfloat, c: Vec4f) =
    verts.add x
    verts.add y
    verts.add z

    #echo "n: ", $n, ", x: ", $x, ", y: ", $y, ", z: ", $z
    add_index()
    colors.add_color c
    #normals.add_normal normal

  for i in  1..<level.height - 1:
    for j in 1..<level.width - 1:
      if j < i - 4: continue
      if j > i + floor_span - 4: continue

      level.map[i,j].cube = newSeq[CubePoint](cube_index.len)
      for w in 0 .. cube_index.high:
        var point = level.cube_point(i, j, w)

        add_point point.pos.x, point.pos.y, point.pos.z, point.color
        level.map[i,j].cube[w] = point

      level.calculate_top_normals(i,j)

      for w in 0 .. cube_index.high:
        let point = level.map[i,j].cube[w]
        normals.add_normal point.normal

      for w in 0 .. cube_index.high:
        let point = level.map[i,j].cube[w]
        uvs.add_uv point.uv

  level.floor_colors  = colors
  level.floor_verts   = verts
  level.floor_index   = index
  level.floor_normals = normals
  level.floor_uvs     = uvs
  #echo "Index length: ", index.len


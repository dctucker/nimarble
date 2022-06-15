
proc cube_point*(level: Level, i,j, w: int): CubePoint =
  let vert = cube_verts[ cube_index[w] ]
  var x = (j - level.origin.x).float + vert.x.float * margin
  var y = level.cube_point_y(i,j,w)
  var z = (i - level.origin.z).float + vert.z.float * margin
  var color_w = cube_colors[w]
  result = CubePoint()

  # hide tiles on the ground
  if level.map[i+0,j+0].height == 0 or
     level.map[i+1,j+0].height == 0 or
     level.map[i+0,j+1].height == 0 or
     level.map[i+1,j+1].height == 0:
    return

  if color_w != 1:
    result.normal = cube_normal(color_w)
  if result.normal.y.classify == fcNaN:
    result.normal = vec3f(0, 1, 0)

  result.uv    = level.point_uv(i, j, w)
  result.color = level.point_color(i, j, w)
  result.pos   = vec3f(x, y, z)

proc update_vbos*(level: Level) {.inline.} =
  # TODO update subset only for performance
  level.floor_plane.vert_vbo.update
  level.floor_plane.color_vbo.update
  level.floor_plane.norm_vbo.update
  level.floor_plane.uv_vbo.update

proc update_vert_vbo*(level: Level)   {.inline.} = level.floor_plane.vert_vbo.update
proc update_normal_vbo*(level: Level) {.inline.} = level.floor_plane.norm_vbo.update
proc update_color_vbo*(level: Level)  {.inline.} = level.floor_plane.color_vbo.update
proc update_index_vbo*(level: Level)  {.inline.} = level.floor_plane.elem_vbo.update
proc update_uv_vbo*(level: Level)     {.inline.} = level.floor_plane.elem_vbo.update

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

proc setup_floor(level: var Level) =
  let dim = level.height * level.width
  var normals = newSeqOfCap[cfloat]( dim )
  var verts   = newSeqOfCap[cfloat]( 3 * dim )
  var index   = newSeqOfCap[Ind]( cube_index.len * dim )
  var colors  = newSeqOfCap[cfloat]( 4 * cube_index.len * dim )
  var uvs     = newSeqOfCap[cfloat]( 3 * cube_index.len * dim )
  var n = 0.Ind
  var x,z: float
  var y: float      #var y0, y1, y2, y3: float

  proc add_index =
    index.add n
    inc n

  proc add_point(x,y,z: cfloat, c: Vec4f) =
    verts.add x
    verts.add y
    verts.add z

    add_index()
    colors.add_color c

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


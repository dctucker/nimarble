
proc igNormal(name: string, normal: var Vec3f): bool {.discardable.} =
  var n0 = normal.θφ
  var d0 = vec2f( n0.θ.degrees, n0.φ.degrees )

  const radius = 16
  const knob_radius = 3
  let color = igGetStyle().colors[ImGuiCol.Text.int32].igGetColorU32
  let knob_color = ImVec4(x: 0.9, y: 0.8, z: 0.0, w: 1.0).igGetColorU32
  let dark = ImVec4(x: 0.4, y: 0.5, z: 0.5, w: 1.0 ).igGetColorU32
  var pos: ImVec2
  igGetCursorScreenPosNonUDT(pos.addr)
  var draw_list = igGetWindowDrawList()
  draw_list.addCircle ImVec2(x: pos.x + radius, y: pos.y + radius), radius, color
  draw_list.addCircle ImVec2(x: pos.x + radius, y: pos.y + radius), knob_radius, dark
  let r = radius * (n0.y / 90f.radians)
  let nx = pos.x + radius + r * cos(n0.x)
  let ny = pos.y + radius + r * sin(n0.x)
  draw_list.addLine        ImVec2(x: pos.x + radius, y: pos.y + radius), ImVec2(x: nx, y: ny), knob_color
  draw_list.addCircleFilled ImVec2(x: nx, y: ny), knob_radius, knob_color
  let size = ImVec2(x: radius * 2, y: radius * 2)
  igInvisibleButton(cstring("##" & name), size)
  #igDummy size

  let io = igGetIO()
  let mouse = vec2f( io.mousePos.x - (pos.x + radius), io.mousePos.y - (pos.y + radius) ) / radius

  let is_hovered = igIsItemHovered()
  let is_active  = igIsItemActive()
  let dragging = igIsMouseDragging(ImGuiMouseButton.Left, 1.0)
  let clicked  = igIsMouseClicked( ImGuiMouseButton.Left)
  var dragged: bool
  if (is_hovered or is_active) and (dragging or clicked):
    dragged = true
    let θ = arctan2(mouse.y, mouse.x)
    let φ = 90f - arccos((mouse.length() * 0.5).clamp(0,1))
    normal.θ = θ
    normal.φ = φ
    #echo θ.degrees, ",", φ.degrees

  igSameLine()
  igBeginGroup()
  let degname = cstring name
  let radname = cstring "θ,φ##" & name
  igPushItemWidth(180 - radius * 2)
  let cartesian = igDragFloat3(degname, normal.arr, 0.01f, -1f, 1f, "%.2f")
  let spherical = igDragFloat2(radname, d0.arr    , 1f, -180f, 180f, "%3.0f°")
  result = cartesian or spherical or dragged

  if spherical:
    normal.θ = d0.x.radians
    normal.φ = d0.y.radians

  igPopItemWidth()
  igEndGroup()

template `|=`(a: var bool, b: bool) =
  a = b or a

proc info_window*(level: var Level, coord: Vec3f) =
  if igBegin("cube"):

    let (i,j) = level.xlat_coord(coord.x.floor, coord.z.floor)
    if not level.has_coord( i,j ): igEnd() ; return

    if level.map[i,j].cube.len == 0:
      for w in 0 .. cube_index.high:
        level.map[i,j].cube.add level.cube_point(i,j,w)

    var gonna_update: bool

    igPushItemWidth(150)

    for s,p in top_points:
      igBeginGroup()
      var gonna_calculate: bool
      var p0 = level.map[i,j].cube[p]
      igDummy(ImVec2(x:0, y:0))
      igSameLine(6)
      gonna_calculate |= igColorEdit4(cstring("color##"  & $p), p0.color.arr, ImGuiColorEditFlags(ImGuiColorEditFlags.NoInputs.ord + ImGuiColorEditFlags.NoLabel.ord) )
      igSameLine(40)
      gonna_calculate |= igDragFloat3(cstring("p"    & $p), p0.pos.arr    , 0.0625, -sky, +sky, "%.2f")
      let normal_edited = igNormal(      "N"         & $p , p0.normal)
      gonna_calculate |= normal_edited
      if gonna_calculate:
        gonna_update = true
        level.calculate_vbos(i,j,p, p0)
        if p in middle_points:
          for m in middle_points:
            var pm = level.map[i,j].cube[m]
            pm.pos = p0.pos
            level.calculate_vbos(i,j,m, pm)
        let a = int(s div 3)
        if normal_edited:
          for b in 0..2:
            let m = top_points[a*3+b]
            var pm = level.map[i,j].cube[m]
            pm.normal = p0.normal
            level.calculate_vbos(i,j,m, pm)
      igEndGroup()
      if s mod 3 == 2:
        igSeparator()
      else:
        igSameLine(235f * ((s+1) mod 3).float)

    for s,p in side_points:
      igBeginGroup()
      var gonna_calculate: bool
      var p0 = level.map[i,j].cube[p]
      igDummy(ImVec2(x:0, y:0))
      igSameLine(6)
      gonna_calculate |= igColorEdit4(cstring("color##side"  & $p), p0.color.arr, ImGuiColorEditFlags(ImGuiColorEditFlags.NoInputs.ord + ImGuiColorEditFlags.NoLabel.ord) )
      igSameLine(40)
      gonna_calculate |= igDragFloat3(cstring("p"    & $p), p0.pos.arr    , 0.0625, -sky, +sky, "%.2f")
      let normal_edited = igNormal(      "N"         & $p , p0.normal)
      gonna_calculate |= normal_edited
      if gonna_calculate:
        gonna_update = true
        level.calculate_vbos(i,j,p, p0)
        if p in middle_points:
          for m in middle_points:
            var pm = level.map[i,j].cube[m]
            pm.pos = p0.pos
            level.calculate_vbos(i,j,m, pm)

      igEndGroup()
      if s mod 3 == 2:
        igSeparator()
      else:
        igSameLine(235f * ((s+1) mod 3).float)

    igPopItemWidth()

    if gonna_update:
      level.update_vbos()
  igEnd()


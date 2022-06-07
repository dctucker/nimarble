
const highlight_width = 16
const line_height = 16
const dark_color = ImVec4(x: 0.2, y: 0.2, z: 0.2, w: 1.0)

proc leave*(editor: var Editor) =
  editor.focused = false
  igFocusWindow(nil)

proc focus*(editor: var Editor) =
  editor.focused = true
  igSetWindowFocus("editor")

action:
  proc do_leave*(editor: var Editor) =
    editor.leave()

  proc do_save(editor: var Editor) =
    editor.level.save()

  proc go_back*(editor: var Editor) =
    if editor.brush:
      editor.brush = false
    elif editor.has_selection():
      editor.select_one()
    else:
      editor.leave()

proc cell_name(editor: Editor): string =
  return cell_name(editor.row, editor.col)

proc cell_value(editor: Editor): string =
  result = ""
  if not editor.cursor_in_level():
    return
  if editor.cursor_data:
    result &= $editor.level.format(editor.get_data())
  if editor.cursor_mask:
    let mask = editor.get_mask()
    if mask != XX:
      result &= " " & $mask

proc draw*(editor: Editor) =
  if not editor.visible: return

  var style = igGetStyle()
  let highlight_color = style.colors[ImGuiCol.TextSelectedBg.int32].igGetColorU32
  let cursor_color    = style.colors[ImGuiCol.Text.int32].igGetColorU32
  let brush_color     = ImVec4(x: 0.4, y: 0.2, z: 0.2, w: 0.7).igGetColorU32

  var color: ImColor
  proc draw_cursor(active: bool) =
    var pos: ImVec2
    igGetCursorScreenPosNonUDT(pos.addr)
    var color = cursor_color
    if not active:
      color = dark_color.igGetColorU32
    var draw_list = igGetWindowDrawList()
    draw_list.addRect ImVec2(x: pos.x - 4, y: pos.y - 1), ImVec2(x: pos.x + 2 + highlight_width, y: pos.y + line_height + 1), color

  proc draw_selected(active: bool) =
    var pos: ImVec2
    igGetCursorScreenPosNonUDT(pos.addr)
    var color = highlight_color
    if editor.brush and active:
      color = brush_color
    var draw_list = igGetWindowDrawList()
    draw_list.addRectFilled ImVec2(x: pos.x - 4, y: pos.y - 1), ImVec2(x: pos.x + 2 + highlight_width, y: pos.y + line_height + 1), color

  proc draw_data_cell(hf: float, enabled: bool = true) =
    let h = hf.int
    var txt = $h
    if txt.len < 2: txt = " " & txt
    var text = txt.cstring

    if h == 0:
      color.value = dark_color
    else:
      const period = 8
      var alpha = 1.0
      let hmod = (h mod period).float / period.float
      let hdiv = (h div period).float / 16f
      var sat  = 0.5
      if hf - hf.floor > 0:
        sat = 0.125
        alpha = 0.5 + (hf - hf.floor) * 0.5
        if hf - hf.floor > 0.5:
          sat = 0.875

      color.addr.setHSV( hmod, sat, 0.4 + hdiv, alpha )

    if not enabled:
      color.value = ImVec4(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
    igTextColored(color.value, text)

  proc draw_mask_cell(m: CliffMask, masks: set[CliffMask], enabled: bool = true) =
    var txt = if m.cliff():
      mask_chars[m] #mask_chars[($m)[0]] & mask_chars[($m)[1]]
    else: $m
    if txt.len < 2: txt = " " & txt
    var text = txt.cstring

    var c = editor.level.mask_color(masks) * 2
    if c.x > 1f: c.x = 1f
    if c.y > 1f: c.y = 1f
    if c.z > 1f: c.z = 1f
    if c.length < 0.4: c = vec4f(0.6,0.6,0.6, 1.0)
    if m == XX:
      if masks == {}:
        c *= dark_color.x
      else:
        c = c * 0.25 + 0.25
    if not enabled:
      c = vec4f(0,0,0,0)
    color.value = ImVec4(x: c.x, y: c.y, z: c.z, w: 1.0)
    igTextColored(color.value, text)

  proc draw_mask_cell(m: CliffMask, enabled: bool = true) =
    draw_mask_cell(m, {m}, enabled)

  proc draw_hbar =
    igSameLine()
    color.value = ImVec4(x: 0, y: 0, z: 0, w: 1.0)
    igTextColored(color.value, " | ")

  #igSetNextWindowSizeConstraints ImVec2(x:300, y:300), ImVec2(x: 1000, y: 1000)
  igBegin("editor")
  var level = editor.level
  if level == nil: return
  var region: ImVec2
  igGetContentRegionAvailNonUDT(region.addr)

  var ww = region.x
  ww /= highlight_width + style.itemSpacing.x
  ww /= 2

  var hh = region.y
  hh /= line_height + style.itemSpacing.y

  editor.width = ww.floor.int
  editor.height = hh.floor.int

  igSameLine()


  let cell = editor.cell_name()
  igText(cell.cstring)
  igSameLine()
  let status = "=" & editor.cell_value()
  igText(status.cstring)
  igNewLine()

  let ew2 = editor.width  div 2
  let eh2 = editor.height div 2
  let last_row = editor.row + eh2
  for i in editor.row - eh2 .. last_row:

    for j in editor.col - ew2 .. editor.col + ew2:
      igSameLine()

      if i == editor.row and j == editor.col:
        draw_cursor(editor.cursor_data)

      if editor.in_selection(i, j):
        draw_selected(editor.cursor_data)

      let hf = level.data[level.offset(i,j)]
      draw_data_cell(hf, editor.level.has_coord(i,j))

    draw_hbar()

    for j in editor.col - ew2 .. editor.col + ew2:
      igSameLine()

      if i == editor.row and j == editor.col:
        draw_cursor(editor.cursor_mask)

      if editor.in_selection(i, j):
        draw_selected(editor.cursor_mask)

      let m = level.mask[level.offset(i,j)]
      draw_mask_cell(m, editor.level.map[i,j].masks, editor.level.has_coord(i,j))

    if i < last_row:
      igNewLine()

  #editor.focused = igIsWindowFocused()
  let editor_window = igGetCurrentWindow()
  igEnd()

  let stamp = editor.stamp
  if stamp.width * stamp.height > 0:
    let tbh = editor_window.titleBarHeight()
    igSetNextWindowSize ImVec2(
      x: (stamp.width * 2 + 1).float  * (highlight_width + style.itemSpacing.x) + style.windowPadding.x * 2 - style.framePadding.x * 2 + style.scrollbarSize,
      y: stamp.height.float * (line_height     + style.itemSpacing.y) + style.windowPadding.y * 2 - style.framePadding.y * 2 + tbh,
    )
    var b = true
    igBegin("stamp", b.addr, (NoFocusOnAppearing.ord or NoScrollbar.ord).ImGuiWindowFlags)
    for i in 0 ..< stamp.height:
      for j in 0 ..< stamp.width:
        igSameLine()
        let o = i * stamp.width + j
        draw_data_cell( stamp.data[o] )
      draw_hbar()
      for j in 0 ..< stamp.width:
        let o = i * stamp.width + j
        igSameLine()
        draw_mask_cell( stamp.mask[o] )
      igNewLine()
    igEnd()


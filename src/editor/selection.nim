
proc all_ints(editor: Editor): bool =
  result = true
  for o in editor.selection_offsets:
    let h = editor.data[o]
    if h - h.floor > 0:
      return false

proc in_selection(editor: Editor, i,j: int): bool =
  result = i >= editor.selection.x and
           i <= editor.selection.z and
           j >= editor.selection.y and
           j <= editor.selection.w

proc cursor_in_selection(editor: Editor): bool =
  result = editor.in_selection(editor.row, editor.col)

proc cursor_in_level(editor: Editor): bool =
  result = editor.level.has_coord(editor.row, editor.col)

proc get_mask(editor: Editor): CliffMask =
  let o = editor.offset()
  return editor.mask[o]

proc update_selector(editor: var Editor) =
  editor.selector.mesh.pos.xz = vec2f(
    editor.selection.y.float - editor.level.origin.x.float,
    editor.selection.x.float - editor.level.origin.z.float,
  )
  editor.selector.mesh.scale.xz = vec2f(
    1 + editor.selection.w.float - editor.selection.y.float,
    1 + editor.selection.z.float - editor.selection.x.float,
  )
  var max_height = 0f
  for i,j in editor.coords(editor.selection):
    let cur = editor.level.map[i,j].height
    if cur > max_height: max_height = cur

  editor.selector.mesh.pos.y  = max_height.float

  if editor.brush:
    editor.selector.mesh.color_vbo.data = addr brush_colors
    editor.selector.mesh.color_vbo.update()
  else:
    editor.selector.mesh.color_vbo.data = addr selector_colors
    editor.selector.mesh.color_vbo.update()

proc update_dirty_vbos(editor: var Editor) =
  for i,j in editor.dirty.items:
    editor.level.calculate_vbos(i, j)
  editor.dirty = @[]
  editor.update_selector()

proc update_selection_vbos(editor: var Editor) =
  for i in editor.selection.x - 1.. editor.selection.z + 1:
    for j in editor.selection.y - 1 .. editor.selection.w + 1:
      editor.level.calculate_vbos(i, j)

proc select_one*(editor: var Editor) =
  editor.selection.x = editor.row.int32
  editor.selection.y = editor.col.int32
  editor.selection.z = editor.row.int32
  editor.selection.w = editor.col.int32
  editor.update_selector()

proc get_selection_stamp(editor: Editor): Stamp =
  result.width = editor.selection.w - editor.selection.y + 1
  result.height = editor.selection.z - editor.selection.x + 1
  let dim = result.width * result.height
  result.data = newSeqOfCap[float](dim)
  result.mask = newSeqOfCap[CliffMask](dim)
  for i in editor.selection.x .. editor.selection.z:
    for j in editor.selection.y .. editor.selection.w:
      if editor.level.has_coord(i,j):
        let o = editor.offset(i,j)
        result.data.add editor.data[o]
        result.mask.add editor.mask[o]
      else:
        result.data.add 0
        result.mask.add XX

proc put_selection_stamp(editor: var Editor, stamp: Stamp, drow, dcol: int) =
  var k: int
  let h = min( editor.selection.z, editor.selection.x + stamp.height - 1 )
  let w = min( editor.selection.w, editor.selection.y + stamp.width  - 1)
  let max_k = min( stamp.data.len, stamp.mask.len )
  for i in editor.selection.x .. h:
    for j in editor.selection.y .. w:
      if editor.level.has_coord(i + drow, j + dcol):
        #let o = editor.offset(i + drow, j + dcol)
        if editor.cursor_mask:
          editor.level[i+drow, j+dcol] = stamp.mask[k]
        if editor.cursor_data:
          editor.level[i+drow, j+dcol] = stamp.data[k]
        editor.invalidate i+drow, j+dcol
      k.inc
      if k >= max_k: return

proc shift_selection(editor: var Editor, drow, dcol: int) =
  editor.selection.x += drow.int32
  editor.selection.y += dcol.int32
  editor.selection.z += drow.int32
  editor.selection.w += dcol.int32

proc brush_selection(editor: var Editor, i, j: int) =
  if not editor.cursor_in_selection():
    return

  let stamp = editor.get_selection_stamp()

  var drow, dcol: int
  if   i < editor.selection.x: drow = i - editor.selection.x
  elif i > editor.selection.z: drow = i - editor.selection.z
  if   j < editor.selection.y: dcol = j - editor.selection.y
  elif j > editor.selection.w: dcol = j - editor.selection.w

  editor.put_selection_stamp(stamp, drow, dcol)

  editor.update_selection_vbos()
  editor.shift_selection(drow, dcol)
  editor.update_selection_vbos()
  editor.level.update_vbos()

  editor.update_selector()

proc has_selection(editor: Editor): bool =
  result = editor.selection.x != editor.selection.z or editor.selection.y != editor.selection.w

proc select_more(editor: var Editor, drow, dcol: int) =
  var i,j: int
  let sel = editor.selection

  template update_cursor =
    editor.row += drow
    editor.col += dcol

  template update_ij =
    i = editor.row
    j = editor.col

  template update_selector =
    editor.update_selector()

  editor.brush = false

  if not editor.cursor_in_selection():
    echo "one"
    editor.select_one()

  if editor.cursor_in_selection():
    update_ij
    if (sel.y + 1 <= j and j <= sel.w - 1) or (sel.x + 1 <= i and i <= sel.z - 1):
      # pan
      echo "pan"
      editor.selection.x += drow.int32
      editor.selection.z += drow.int32
      editor.selection.y += dcol.int32
      editor.selection.w += dcol.int32
      update_cursor
      update_selector
      return

  update_ij

  if editor.in_selection(editor.row + drow, editor.col + dcol):
    # shrink
    echo "shrink"
    update_cursor

    if j - sel.y < sel.w - j:
      editor.selection.y = editor.col.int32
    else:
      editor.selection.w = editor.col.int32

    if i - sel.x < sel.z - i:
      editor.selection.x = editor.row.int32
    else:
      editor.selection.z = editor.row.int32

  else:
    # grow
    echo "grow"
    update_cursor
    update_ij
    if j > sel.w: editor.selection.w = j.int32
    if j < sel.y: editor.selection.y = j.int32
    if i > sel.z: editor.selection.z = i.int32
    if i < sel.x: editor.selection.x = i.int32

  update_selector


action:
  proc do_select_one*(editor: var Editor) = editor.select_one()

  proc select_all*(editor: var Editor) =
    editor.brush = false
    let (x,y) = editor.level.find_first()
    let (z,w) = editor.level.find_last()
    editor.selection.x = x.int32 - 1
    editor.selection.y = y.int32 - 1
    editor.selection.z = z.int32 + 1
    editor.selection.w = w.int32 + 1
    editor.update_selector()

  proc select_none*(editor: var Editor) =
    editor.brush = false
    editor.select_one()

  proc toggle_brush*(editor: var Editor) =
    editor.brush = not editor.brush
    if editor.has_selection() and not editor.cursor_in_selection():
      editor.select_one()
    editor.update_selector()

proc delete_selection(editor: var Editor, data: var seq[float]) =
  for i,j in editor.selection_coords:
    editor.level[i,j] = 0
    editor.dirty.add (i,j)

proc delete_selection(editor: var Editor, mask: var seq[CliffMask]) =
  for i,j in editor.selection_coords:
    editor.level[i,j] = XX
    editor.dirty.add (i,j)

proc all_zero(editor: Editor, data: var seq[float]): bool =
  result = true
  for o in editor.selection_offsets:
    if data[o] != 0:
      return false

proc all_zero(editor: Editor, mask: var seq[CliffMask]): bool =
  result = true
  for o in editor.selection_offsets:
    if mask[o] != XX:
      return false


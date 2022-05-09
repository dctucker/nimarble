from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper, getClipboardString, setClipboardString
import nimgl/imgui
import glm
import strutils

import leveldata
import types

const highlight_width = 16
const line_height = 16
const dark_color = ImVec4(x: 0.2, y: 0.2, z: 0.2, w: 1.0)

proc leave(editor: Editor) =
  editor.focused = false
  igFocusWindow(nil)

proc offset[T: Ordinal](editor: Editor, row, col: T): int =
  result = editor.level.offset( row, col ).int

proc offset(editor: Editor): int =
  result = editor.offset( editor.row, editor.col )

iterator offsets(editor: Editor, rect: Vec4i): int =
  for i in rect.x .. rect.z:
    for j in rect.y .. rect.w:
      yield editor.offset(i,j)

iterator offsets(editor: Editor): int =
  #let all = vec4i( x: 0, y: 0, z: editor.level.height - 1, w: editor.level.width - 1)
  let all = vec4i( 0.int32, 0.int32, editor.level.height.int32 - 1, editor.level.width.int32 - 1)
  for o in editor.offsets(all): yield o

iterator selection_offsets(editor: Editor): int =
  for o in editor.offsets(editor.selection): yield o
iterator cut_offsets(editor: Editor): int =
  for o in editor.offsets(editor.cut): yield o

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

proc get_data(editor: Editor): float =
  let o = editor.offset()
  return editor.data[o]

proc set_data(editor: Editor, value: float) =
  let o = editor.offset()
  editor.data[o] = value
  editor.dirty = true

proc update_selection_vbos(editor: Editor) =
  for i in editor.selection.x - 1.. editor.selection.z + 1:
    for j in editor.selection.y - 1 .. editor.selection.w + 1:
      editor.level.calculate_vbos(i, j)

proc inc_dec(editor: Editor, d: float) =
  editor.dirty = true
  if editor.cursor_in_selection():
    for o in editor.selection_offsets():
      let h = editor.data[o]
      if h == 0:
        continue
      var value = h + d
      if d == 1:
        value = value.int.float
      editor.data[o] = value
    editor.update_selection_vbos()
  else:
    let h = editor.get_data()
    if h == 0:
      return
    var value = h + d
    if d == 1:
      value = value.int.float
    editor.set_data (h + d).int.float

proc inc(editor: Editor) =
  var d = 1f
  if editor.input.contains(".") or not editor.all_ints():
    d = 0.125
  editor.inc_dec(d)

proc dec(editor: Editor) =
  var d = -1f
  if editor.input.contains(".") or not editor.all_ints():
    d = -0.125
  editor.inc_dec(d)

proc set_number(editor: Editor, num: int) =
  var value: float
  if editor.input.len < 2:
    editor.input = "  "
  if editor.input.contains ".":
    editor.input &= $num
  else:
    editor.input = editor.input[1..^1] & $num
  value = (editor.input.strip()).parseFloat
  editor.set_data value

proc decimal(editor: Editor) =
  if editor.input.contains ".":
    return
  editor.input &= "."

proc set_mask(editor: Editor, mask: CliffMask) =
  var m = mask
  let o = editor.offset()
  let cur = editor.mask[o]
  if   cur == RH or cur == RI:
    if   mask == HH: m = RH
    elif mask == II: m = RI
  elif cur == EY or cur == EM:
    if   mask == AA: m = EA
    if   mask == P1: m = EP
    if   mask == HH: m = EH
    if   mask == VV: m = EV
  elif cur == P1:
    if   mask == P1: m = P2
  elif mask.cliff():
    if cur.cliff():
      m = CliffMask(cur.ord xor mask.ord)
    else:
      m = mask

  editor.mask[o] = m
  editor.dirty = true

proc select_one(editor: Editor) =
  editor.selection.x = editor.row.int32
  editor.selection.y = editor.col.int32
  editor.selection.z = editor.row.int32
  editor.selection.w = editor.col.int32

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

proc put_selection_stamp(editor: Editor, stamp: Stamp, drow, dcol: int) =
  var k: int
  let h = min( editor.selection.z, editor.selection.x + stamp.height - 1 )
  let w = min( editor.selection.w, editor.selection.y + stamp.width  - 1)
  let max_k = min( stamp.data.len, stamp.mask.len )
  for i in editor.selection.x .. h:
    for j in editor.selection.y .. w:
      if editor.level.has_coord(i + drow, j + dcol):
        let o = editor.offset(i + drow, j + dcol)
        if editor.cursor_data:
          editor.data[o] = stamp.data[k]
        if editor.cursor_mask:
          editor.mask[o] = stamp.mask[k]
      k.inc
      if k >= max_k: return

proc shift_selection(editor: Editor, drow, dcol: int) =
  editor.selection.x += drow.int32
  editor.selection.y += dcol.int32
  editor.selection.z += drow.int32
  editor.selection.w += dcol.int32

proc brush_selection(editor: Editor, i, j: int) =
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

proc has_selection(editor: Editor): bool =
  result = editor.selection.x != editor.selection.z or editor.selection.y != editor.selection.w

proc cursor(editor: Editor, drow, dcol: int) =
  editor.input = ""
  if editor.brush:
    if editor.has_selection():
      editor.brush_selection(editor.row + drow, editor.col + dcol)
    else:
      let cur_o = editor.offset()
      let next_o = editor.offset( editor.row+drow, editor.col+dcol )
      if 0 < next_o and next_o < editor.data.len:
        editor.data[ next_o ] = editor.data[ cur_o ]
        editor.mask[ next_o ] = editor.mask[ cur_o ]
        editor.dirty = true

  editor.row += drow
  editor.col += dcol

  if editor.selection.xy == editor.selection.zw:
    editor.select_one()

proc select_more(editor: Editor, drow, dcol: int) =
  var i,j: int
  let sel = editor.selection

  template update_cursor =
    editor.row += drow
    editor.col += dcol

  template update_ij =
    i = editor.row
    j = editor.col

  editor.brush = false

  if not editor.cursor_in_selection():
    editor.select_one()

  if editor.cursor_in_selection():
    update_ij
    if (sel.y + 1 <= j and j <= sel.w - 1) or (sel.x + 1 <= i and i <= sel.z - 1):
      # pan
      editor.selection.x += drow.int32
      editor.selection.z += drow.int32
      editor.selection.y += dcol.int32
      editor.selection.w += dcol.int32
      update_cursor
      return

  update_ij

  if editor.in_selection(editor.row + drow, editor.col + dcol):
    # shrink
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
    update_cursor
    update_ij
    if j < sel.y: editor.selection.y = j.int32
    if j > sel.w: editor.selection.w = j.int32
    if i < sel.x: editor.selection.x = i.int32
    if i > sel.z: editor.selection.z = i.int32

proc toggle_brush*(editor: Editor) =
  editor.brush = not editor.brush
  if editor.has_selection() and not editor.cursor_in_selection():
    editor.select_one()

proc delete_selection(editor: Editor, data: var seq[float]) =
  for o in editor.selection_offsets:
    data[o] = 0

proc delete_selection(editor: Editor, mask: var seq[CliffMask]) =
  for o in editor.selection_offsets:
    mask[o] = XX

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

proc delete(editor: Editor) =
  editor.dirty = true
  editor.input = ""

  if editor.cursor_in_selection():
    var zero: bool
    if editor.cursor_data:
      zero = editor.all_zero(editor.data)
      if zero:
        editor.delete_selection(editor.mask)
      else:
        editor.delete_selection(editor.data)
    if editor.cursor_mask:
      zero = editor.all_zero(editor.mask)
      if zero:
        editor.delete_selection(editor.data)
      else:
        editor.delete_selection(editor.mask)
    return

  let o = editor.offset()
  if editor.data[o] == 0:
    editor.mask[o] = XX
    return
  editor.data[o] = 0

proc save(editor: Editor) =
  editor.level.save()

proc serialize_selection[T](editor: Editor, data: seq[T]): string =
  result = ""
  for i in editor.selection.x .. editor.selection.z:
    for j in editor.selection.y .. editor.selection.w:
      let o = editor.offset(i,j)
      result.add editor.level.format(data[o]) & "\t"
    result = result[0..^2] & "\n"
  result = result[0..^2]

proc serialize_selection(editor: Editor): string =
  if editor.cursor_mask:
    return editor.serialize_selection(editor.mask)
  if editor.cursor_data:
    return editor.serialize_selection(editor.data)

proc undo(editor: Editor) = discard
proc redo(editor: Editor) = discard

proc copy_clipboard(editor: Editor) =
  setClipboardString nil, editor.serialize_selection().cstring
  editor.cut = vec4i(0,0,0,0)

proc cut_clipboard(editor: Editor) =
  editor.copy_clipboard()
  editor.cut = editor.selection

proc execute_cut(editor: Editor) =
  editor.dirty = true
  if editor.cut != vec4i(0,0,0,0):
    for o in editor.cut_offsets:
      if editor.cursor_mask:
        editor.mask[o] = XX
      if editor.cursor_data:
        editor.data[o] = 0f
    editor.cut = vec4i(0,0,0,0)

proc paste_clipboard(editor: Editor) =
  editor.execute_cut()
  let clip = $getClipboardString(nil)
  var i = editor.row
  for line in clip.split("\n"):
    var j = editor.col
    for value in line.split("\t"):
      let o = editor.offset(i, j)
      if editor.cursor_mask:
        editor.mask[o] = editor.level.parseMask(value)
      if editor.cursor_data:
        editor.data[o] = editor.level.parseFloat(value)
      j.inc
    i.inc

proc copy_both(editor: Editor) =
  editor.cursor_mask = true
  editor.cursor_data = true
  editor.stamp = editor.get_selection_stamp()
  editor.cut = vec4i(0,0,0,0)

proc cut_both(editor: Editor) =
  editor.copy_both()
  editor.cut = editor.selection

proc paste_both(editor: Editor) =
  editor.cursor_mask = true
  editor.cursor_data = true
  editor.execute_cut()
  editor.selection = vec4i( editor.row.int32, editor.col.int32, editor.row.int32 + editor.stamp.height.int32 - 1, editor.col.int32 + editor.stamp.width.int32 - 1)
  editor.put_selection_stamp(editor.stamp, 0, 0)
  editor.dirty = true

proc do_copy(editor: Editor) =
  if editor.cursor_mask == true and editor.cursor_data == true:
    editor.copy_both()
  else:
    editor.copy_clipboard()

proc do_cut(editor: Editor) =
  if editor.cursor_mask == true and editor.cursor_data == true:
    editor.cut_both()
  else:
    editor.cut_clipboard()

proc do_paste(editor: Editor) =
  if editor.cursor_mask == true and editor.cursor_data == true:
    editor.paste_both()
  else:
    editor.paste_clipboard()

proc back(editor: Editor) =
  if editor.brush:
    editor.brush = false
  elif editor.has_selection():
    editor.select_one()
  else:
    editor.leave()

proc toggle_cursor(editor: Editor) =
  editor.cursor_mask = not editor.cursor_mask
  editor.cursor_data = not editor.cursor_mask

proc cursor_both(editor: Editor) =
  editor.cursor_mask = true
  editor.cursor_data = true

proc rotate_stamp(editor: Editor) =
  let s1 = editor.stamp
  let w = s1.width
  let dim = s1.height * w
  var s2 = Stamp(
    width : s1.height,
    height: s1.width,
    data: newSeqOfCap[float](dim),
    mask: newSeqOfCap[CliffMask](dim),
  )
  for j in 0 ..< w:
    for i in countdown(s1.height - 1,  0):
      let o1 = w * i + j
      s2.data.add s1.data[o1]
      s2.mask.add s1.mask[o1]
  editor.stamp = s2

proc flip_stamp(editor: Editor) =
  let s1 = editor.stamp
  let w = s1.width
  let dim = s1.height * w
  var s2 = Stamp(
    width : s1.width,
    height: s1.height,
    data: newSeqOfCap[float](dim),
    mask: newSeqOfCap[CliffMask](dim),
  )
  for i in countdown(editor.stamp.height - 1, 0):
    for j in 0 ..< editor.stamp.width:
      let o = w * i + j
      s2.data.add s1.data[o]
      s2.mask.add s1.mask[o]
  editor.stamp = s2

proc reverse_stamp(editor: Editor) =
  let s1 = editor.stamp
  let w = s1.width
  let dim = s1.height * w
  var s2 = Stamp(
    width : s1.width,
    height: s1.height,
    data: newSeqOfCap[float](dim),
    mask: newSeqOfCap[CliffMask](dim),
  )
  for i in 0 ..< editor.stamp.height:
    for j in countdown(editor.stamp.width - 1, 0):
      let o = w * i + j
      s2.data.add s1.data[o]
      s2.mask.add s1.mask[o]
  editor.stamp = s2

proc handle_key*(editor: Editor, key: int32, mods: int32): bool =
  #let io = igGetIO()
  #if not io.wantCaptureMouse:
  #  return

  result = true
  if (mods and GLFWModControl) != 0 or (mods and GLFWModSuper) != 0:
    #if (mods and GLFWModShift) != 0:
    #  case key
    #  of GLFWKey.Z          : editor.redo()
    #  of GLFWKey.X          : editor.cut_both()
    #  of GLFWKey.C          : editor.copy_both()
    #  of GLFWKey.V          : editor.paste_both()
    #  else                  : result = false
    #else:
      case key
      of GLFWKey.Y          : editor.redo()
      of GLFWKey.Z          : editor.undo()
      of GLFWKey.X          : editor.do_cut()
      of GLFWKey.C          : editor.do_copy()
      of GLFWKey.V          : editor.do_paste()
      else                  : result = false
  elif (mods and GLFWModShift) != 0:
    case key
    of GLFWKey.Up         : editor.select_more(-1, 0)
    of GLFWKey.Down       : editor.select_more(+1, 0)
    of GLFWKey.Left       : editor.select_more( 0,-1)
    of GLFWKey.Right      : editor.select_more( 0,+1)
    of GLFWKey.PageUp     : editor.select_more(-1,-1)
    of GLFWKey.PageDown   : editor.select_more(+1,+1)
    of GLFWKey.Home       : editor.select_more(+1,-1)
    of GLFWKey.End        : editor.select_more(-1,+1)
    of GLFWKey.Tab        : editor.cursor_both()
    of GLFWKey.Minus      : editor.flip_stamp()
    of GLFWKey.Backslash  : editor.reverse_stamp()
    else                  : editor.select_one()
  else:
    case key
    of GLFWKey.E          : editor.leave()
    of GLFWKey.B          : editor.toggle_brush()
    of GLFWKey.Escape     : editor.back()
    of GLFWKey.Up         : editor.cursor(-1, 0)
    of GLFWKey.Down       : editor.cursor(+1, 0)
    of GLFWKey.Left       : editor.cursor( 0,-1)
    of GLFWKey.Right      : editor.cursor( 0,+1)
    of GLFWKey.PageUp     : editor.cursor(-1,-1)
    of GLFWKey.PageDown   : editor.cursor(+1,+1)
    of GLFWKey.Home       : editor.cursor(+1,-1)
    of GLFWKey.End        : editor.cursor(-1,+1)
    of GLFWKey.Minus      ,
       GLFWKey.KpSubtract : editor.dec
    of GLFWKey.Equal      ,
       GLFWKey.KpAdd      : editor.inc
    of GLFWKey.Period,
       KpDecimal          : editor.decimal()
    of GLFWKey.K0,
       K1, K2, K3,
       K4, K5, K6,
       K7, K8, K9         : editor.set_number(key.ord - GLFWKey.K0.ord)
    of GLFWKey.Backspace,
       GLFWKey.Delete     : editor.delete()
    of GLFWKey.X          : editor.set_mask(XX)
    of GLFWKey.C          : editor.set_mask(IC)
    of GLFWKey.U          : editor.set_mask(CU)
    of GLFWKey.L          : editor.set_mask(LL)
    of GLFWKey.V          : editor.set_mask(VV)
    of GLFWKey.A          : editor.set_mask(AA)
    of GLFWKey.J          : editor.set_mask(JJ)
    of GLFWKey.I          : editor.set_mask(II)
    of GLFWKey.H          : editor.set_mask(HH)
    of GLFWKey.R          : editor.set_mask(RH)
    of GLFWKey.G          : editor.set_mask(GG)
    of GLFWKey.S          : editor.set_mask(SW)
    of GLFWKey.P          : editor.set_mask(P1)
    of GLFWKey.M          : editor.set_mask(EM)
    of GLFWKey.Y          : editor.set_mask(EY)
    of GLFWKey.T          : editor.set_mask(TU)
    of GLFWKey.N          : editor.set_mask(IN)
    of GLFWKey.O          : editor.set_mask(OU)
    of GLFWKey.Tab        : editor.toggle_cursor()
    of GLFWKey.Slash      : editor.rotate_stamp()
    of GLFWKey.W          : editor.save()
    #of GLFWKey.LeftShift  : editor.select_one()
    else                  : result = false

  if editor.dirty:
    for i in -1 .. 1:
      for j in -1 .. 1:
        editor.level.calculate_vbos(editor.row + i, editor.col + j)
    if editor.has_selection():
      editor.update_selection_vbos()
    editor.level.update_vbos()
    editor.dirty = false

proc letter(j: int): string =
  result = ""
  var v = j
  var c = 0

  if j < 0:
    return ""
  if j < 26:
    return $char(j + 65)
  if j < 676:
    c = v mod 26
    v = j div 26
    return $char(v + 64) & $char(c + 65)
  else:
    return "MAX"

proc cell_name(editor: Editor): string =
  result = editor.col.letter
  if editor.row < 0:
    return
  result &= $(editor.row + 1)

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
    draw_list.addRect ImVec2(x: pos.x - 3, y: pos.y - 1), ImVec2(x: pos.x + 3 + highlight_width, y: pos.y + line_height + 1), color

  proc draw_selected(active: bool) =
    var pos: ImVec2
    igGetCursorScreenPosNonUDT(pos.addr)
    var color = highlight_color
    if editor.brush and active:
      color = brush_color
    var draw_list = igGetWindowDrawList()
    draw_list.addRectFilled ImVec2(x: pos.x - 3, y: pos.y - 1), ImVec2(x: pos.x + 3 + highlight_width, y: pos.y + line_height + 1), color

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

  proc draw_mask_cell(m: CliffMask, enabled: bool = true) =
    var txt = $m
    if txt.len < 2: txt = " " & txt
    var text = txt.cstring

    #const period = 10
    #let hmod = 0.6 + 0.1 * sin( 2 * 3.14159265 * (h mod period).float / period.float )
    color.value = ImVec4(x: 0.8, y: 0.8, z: 0.8, w: 1.0)
    if m == XX: color.value = dark_color
    if not enabled:
      color.value = ImVec4(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
    igTextColored(color.value, text)

  proc draw_hbar =
    igSameLine()
    color.value = ImVec4(x: 0, y: 0, z: 0, w: 1.0)
    igTextColored(color.value, " | ")

  igSetNextWindowSizeConstraints ImVec2(x:300, y:300), ImVec2(x: 1000, y: 1000)
  igBegin("editor")
  var level = editor.level
  if level == nil: return

  var wh = igGetWindowWidth()
  wh -= style.windowPadding.x * 2 - style.framePadding.x * 2
  wh -= highlight_width * 2
  wh /= 2
  wh /= highlight_width + style.itemSpacing.x
  editor.width = wh.floor.int

  igSameLine()


  let cell = editor.cell_name()
  igText(cell.cstring)
  igSameLine()
  let status = "=" & editor.cell_value()
  igText(status.cstring)
  igNewLine()

  let ew2 = editor.width div 2
  let last_row = editor.row + ew2
  for i in editor.row - ew2 .. last_row:

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
      draw_mask_cell(m, editor.level.has_coord(i,j))

    if i < last_row:
      igNewLine()

  editor.focused = igIsWindowFocused()
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


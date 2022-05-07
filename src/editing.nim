from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper, getClipboardString, setClipboardString
import nimgl/imgui
import glm
import strutils

from leveldata import save, format, parseFloat, parseMask
import types

const highlight_width = 16
const line_height = 16
const dark_color = ImVec4(x: 0.2, y: 0.2, z: 0.2, w: 1.0)

proc offset(editor: Editor, row, col: int): int =
  result = editor.level.offset( row, col )

proc offset(editor: Editor): int =
  result = editor.offset( editor.row, editor.col )

proc inc(editor: Editor) =
  let o = editor.offset()
  let h = editor.level.data[o]
  editor.level.data[o] = (h + 1).int.float
  editor.dirty = true

proc dec(editor: Editor) =
  let o = editor.offset()
  let h = editor.level.data[o]
  editor.level.data[o] = (h - 1).int.float
  editor.dirty = true

proc leave(editor: Editor) =
  editor.focused = false
  igFocusWindow(nil)

proc set_data(editor: Editor, value: float) =
  let o = editor.offset()
  let cur = editor.level.data[o]
  editor.level.data[o] = value

proc set_number(editor: Editor, num: int) =
  if editor.input.len < 2:
    editor.input = "  "
  editor.input = editor.input[1..^1] & $num
  let value: float = (editor.input.strip()).parseFloat
  editor.set_data value
  echo editor.input

proc set_mask(editor: Editor, mask: CliffMask) =
  var m = mask
  let o = editor.offset()
  let cur = editor.level.mask[o]
  if   cur == RH or cur == RI:
    if   mask == HH: m = RH
    elif mask == II: m = RI
  elif cur == EY or cur == EM:
    if   mask == AA: m = EA
  elif mask.cliff():
    if cur.cliff():
      m = CliffMask(cur.ord xor mask.ord)
    else:
      m = mask

  editor.level.mask[o] = m

proc select_one(editor: Editor) =
  editor.selection.x = editor.row.int32
  editor.selection.y = editor.col.int32
  editor.selection.z = editor.row.int32
  editor.selection.w = editor.col.int32

proc in_selection(editor: Editor, i,j: int): bool =
  result = i >= editor.selection.x and
           i <= editor.selection.z and
           j >= editor.selection.y and
           j <= editor.selection.w

proc cursor_in_selection(editor: Editor): bool =
  result = editor.in_selection(editor.row, editor.col)

proc brush_selection(editor: Editor, i,j: int) =
  if not editor.cursor_in_selection():
    return

  let dim = (editor.selection.z - editor.selection.x) * (editor.selection.w - editor.selection.y)
  var stamp_data = newSeqOfCap[float](dim)
  var stamp_mask = newSeqOfCap[CliffMask](dim)
  for i in editor.selection.x .. editor.selection.z:
    for j in editor.selection.y .. editor.selection.w:
      let o = editor.offset(i,j)
      stamp_data.add editor.level.data[o]
      stamp_mask.add editor.level.mask[o]

  var oi, oj: int
  if   i < editor.selection.x: oi = i - editor.selection.x
  elif i > editor.selection.z: oi = i - editor.selection.z
  if   j < editor.selection.y: oj = j - editor.selection.y
  elif j > editor.selection.w: oj = j - editor.selection.w

  var k = 0
  for i in editor.selection.x .. editor.selection.z:
    for j in editor.selection.y .. editor.selection.w:
      let o = editor.offset(i + oi, j + oj)
      editor.level.data[o] = stamp_data[k]
      editor.level.mask[o] = stamp_mask[k]
      k.inc

  editor.selection.x += oi.int32
  editor.selection.y += oj.int32
  editor.selection.z += oi.int32
  editor.selection.w += oj.int32

proc has_selection(editor: Editor): bool =
  result = editor.selection.x != editor.selection.z or editor.selection.y != editor.selection.w

proc cursor(editor: Editor, drow, dcol: int) =
  if editor.brush:
    if editor.has_selection():
      editor.brush_selection(editor.row + drow, editor.col + dcol)
    else:
      let cur_o = editor.offset()
      let next_o = editor.offset( editor.row+drow, editor.col+dcol )
      if 0 < next_o and next_o < editor.level.data.len:
        editor.level.data[ next_o ] = editor.level.data[ cur_o ]
        editor.level.mask[ next_o ] = editor.level.mask[ cur_o ]
        editor.dirty = true

  editor.row += drow
  editor.col += dcol

  if editor.selection.xy == editor.selection.zw:
    editor.select_one()

proc select_more(editor: Editor, drow, dcol: int) =
  editor.brush = false

  if not editor.cursor_in_selection():
    editor.select_one()

  editor.row += drow
  editor.col += dcol

  if editor.row < editor.selection.x: editor.selection.x = editor.row.int32
  if editor.col < editor.selection.y: editor.selection.y = editor.col.int32

  if editor.row > editor.selection.z: editor.selection.z = editor.row.int32
  if editor.col > editor.selection.w: editor.selection.w = editor.col.int32

proc toggle_brush*(editor: Editor) =
  editor.brush = not editor.brush
  if editor.has_selection() and not editor.cursor_in_selection():
    editor.select_one()

proc delete(editor: Editor) =
  editor.dirty = true
  let o = editor.offset()
  if editor.level.data[o] == 0:
    editor.level.mask[o] = XX
    return
  editor.level.data[o] = 0

proc save(editor: Editor) =
  editor.level.save(editor.name)

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
    return editor.serialize_selection(editor.level.mask)
  if editor.cursor_data:
    return editor.serialize_selection(editor.level.data)

proc undo(editor: Editor) = discard
proc redo(editor: Editor) = discard

proc copy_clipboard(editor: Editor) =
  setClipboardString nil, editor.serialize_selection()
  editor.cut = vec4i(0,0,0,0)

proc cut_clipboard(editor: Editor) =
  editor.copy_clipboard()
  editor.cut = editor.selection

proc execute_cut(editor: Editor) =
  if editor.cut != vec4i(0,0,0,0):
    for i in editor.cut.x .. editor.cut.z:
      for j in editor.cut.y .. editor.cut.w:
        let o = editor.offset(i, j)
        if editor.cursor_mask:
          editor.level.mask[o] = XX
        if editor.cursor_data:
          editor.level.data[o] = 0f
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
        editor.level.mask[o] = editor.level.parseMask(value)
      if editor.cursor_data:
        editor.level.data[o] = editor.level.parseFloat(value)
      j.inc
    i.inc

#proc cut_both()
#  editor.cursor_mask = true
#  editor.cursor_data = true
#  editor.cut_clipboard()
#
#proc paste_both()
#  editor.cursor_mask = true
#  editor.cursor_data = true
#  editor.paste_clipboard()
#
#proc copy_both()
#  editor.cursor_mask = true
#  editor.cursor_data = true
#  editor.copy_clipboard()


proc toggle_cursor(editor: Editor) =
  editor.cursor_mask = not editor.cursor_mask
  editor.cursor_data = not editor.cursor_mask

proc handle_key*(editor: Editor, key: int32, mods: int32): bool =
  #let io = igGetIO()
  #if not io.wantCaptureMouse:
  #  return

  result = true
  if (mods and GLFWModControl) != 0 or (mods and GLFWModSuper) != 0:
    if (mods and GLFWModShift) != 0:
      #case key
      #of GLFWKey.Z          : editor.redo()
      #of GLFWKey.X          : editor.cut_both()
      #of GLFWKey.C          : editor.copy_both()
      #of GLFWKey.V          : editor.paste_both()
      #else                  : result = false
      return
    else:
      case key
      of GLFWKey.Y          : editor.redo()
      of GLFWKey.Z          : editor.undo()
      of GLFWKey.X          : editor.cut_clipboard()
      of GLFWKey.C          : editor.copy_clipboard()
      of GLFWKey.V          : editor.paste_clipboard()
      else                  : result = false
      return
  if (mods and GLFWModShift) != 0:
    case key
    of GLFWKey.Up         : editor.select_more(-1, 0)
    of GLFWKey.Down       : editor.select_more(+1, 0)
    of GLFWKey.Left       : editor.select_more( 0,-1)
    of GLFWKey.Right      : editor.select_more( 0,+1)
    of GLFWKey.PageUp     : editor.select_more(-1,-1)
    of GLFWKey.PageDown   : editor.select_more(+1,+1)
    of GLFWKey.Home       : editor.select_more(+1,-1)
    of GLFWKey.End        : editor.select_more(-1,+1)
    else                  : editor.select_one()
    return

  case key
  of GLFWKey.E          : editor.leave()
  of GLFWKey.B          : editor.toggle_brush()
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
  of GLFWKey.K0,
     K1, K2, K3,
     K4, K5, K6,
     K7, K8, K9         : editor.set_number(key.ord - GLFWKey.K0.ord)
  of GLFWKey.Backspace  : editor.delete()
  of GLFWKey.X          : editor.set_mask(XX)
  of GLFWKey.C          : editor.set_mask(IC)
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
  of GLFWKey.W          : editor.save()
  of GLFWKey.Tab        : editor.toggle_cursor()
  #of GLFWKey.LeftShift  : editor.select_one()
  else                  : result = false


proc draw*(editor: Editor) =
  igSetNextWindowSizeConstraints ImVec2(x:300, y:300), ImVec2(x: 1000, y: 1000)
  igBegin("editor")
  var level = editor.level
  if level == nil: return
  var style = igGetStyle()
  let highlight_color = style.colors[ImGuiCol.TextSelectedBg.int32].igGetColorU32
  let cursor_color    = style.colors[ImGuiCol.Text.int32].igGetColorU32
  let brush_color     = ImVec4(x: 0.4, y: 0.2, z: 0.2, w: 0.7).igGetColorU32

  igSameLine()

  var color: ImColor
  var draw_list = igGetWindowDrawList()

  proc draw_cursor =
    var pos: ImVec2
    igGetCursorScreenPosNonUDT(pos.addr)
    draw_list.addRect ImVec2(x: pos.x - 3, y: pos.y - 1), ImVec2(x: pos.x + 3 + highlight_width, y: pos.y + line_height + 1), cursor_color

  proc draw_selected =
    var pos: ImVec2
    igGetCursorScreenPosNonUDT(pos.addr)
    var color = highlight_color
    if editor.brush:
      color = brush_color
    draw_list.addRectFilled ImVec2(x: pos.x - 3, y: pos.y - 1), ImVec2(x: pos.x + 3 + highlight_width, y: pos.y + line_height + 1), color

  for i in editor.row - 5 .. editor.row + 5:
    for j in editor.col - 5 .. editor.col + 5:
      igSameLine()

      if (not editor.cursor_mask) and i == editor.row and j == editor.col:
        draw_cursor()

      if editor.in_selection(i, j):
        draw_selected()

      let h = level.data[level.offset(i,j)].int
      var txt = $h
      if txt.len < 2: txt = " " & txt
      var text = txt.cstring

      if h == 0:
        color.value = dark_color
      else:
        const period = 8
        let hmod = (h mod period).float / period.float
        let hdiv = (h div period).float / 16f

        color.addr.setHSV( hmod, 0.5, 0.4 + hdiv, 1.0 )

      igTextColored(color.value, text)

    igSameLine()
    color.value = ImVec4(x: 0, y: 0, z: 0, w: 1.0)
    igTextColored(color.value, " | ")

    for j in editor.col - 5 .. editor.col + 5:
      igSameLine()

      if editor.cursor_mask and i == editor.row and j == editor.col:
        draw_cursor()

      if editor.in_selection(i, j):
        draw_selected()

      let m = level.mask[level.offset(i,j)]
      var txt = $m
      if txt.len < 2: txt = " " & txt
      var text = txt.cstring

      #const period = 10
      #let hmod = 0.6 + 0.1 * sin( 2 * 3.14159265 * (h mod period).float / period.float )
      color.value = ImVec4(x: 0.8, y: 0.8, z: 0.8, w: 1.0)
      if m == XX: color.value = dark_color
      igTextColored(color.value, text)

    igText("")

    editor.focused = igIsWindowFocused()

  igEnd()


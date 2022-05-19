{. warning[HoleEnumConv]:off .}
import std/tables

from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper, getClipboardString, setClipboardString
import nimgl/imgui
import glm
import strutils

import leveldata
import types
import masks
from keymapper import action

const highlight_width = 16
const line_height = 16
const dark_color = ImVec4(x: 0.2, y: 0.2, z: 0.2, w: 1.0)

proc leave*(editor: var Editor) =
  editor.focused = false
  igFocusWindow(nil)

action:
  proc do_leave*(editor: var Editor) =
    editor.leave()

proc focus*(editor: var Editor) =
  editor.focused = true
  igSetWindowFocus("editor")

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

proc set_data(editor: var Editor, value: float) =
  let o = editor.offset()
  editor.data[o] = value
  editor.dirty = true

proc update_selection_vbos(editor: var Editor) =
  for i in editor.selection.x - 1.. editor.selection.z + 1:
    for j in editor.selection.y - 1 .. editor.selection.w + 1:
      editor.level.calculate_vbos(i, j)

proc inc_dec(editor: var Editor, d: float) =
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

action:
  proc do_inc*(editor: var Editor) =
    var d = 1f
    if editor.input.contains(".") or not editor.all_ints():
      d = 0.125
    editor.inc_dec(d)

  proc do_dec*(editor: var Editor) =
    var d = -1f
    if editor.input.contains(".") or not editor.all_ints():
      d = -0.125
    editor.inc_dec(d)

proc set_number(editor: var Editor, num: int) =
  var value: float
  if editor.input.len < 2:
    editor.input = "  "
  if editor.input.contains ".":
    editor.input &= $num
  else:
    editor.input = editor.input[1..^1] & $num
  value = (editor.input.strip()).parseFloat
  editor.set_data value

action:
  proc input_decimal*(editor: var Editor) =
    if editor.input.contains ".":
      return
    editor.input &= "."

  proc input_number*(editor: var Editor) =
    editor.set_number(editor.recent_input.ord - K0.ord)

proc set_mask(editor: var Editor, mask: CliffMask) =
  var m = mask
  let o = editor.offset()
  let cur = editor.mask[o]
  if   cur == RH or cur == RI:
    if   mask == HH: m = RH
    elif mask == II: m = RI
    elif mask == GG: m = GR
  elif cur == BH or cur == BI:
    if   mask == HH: m = BH
    elif mask == II: m = BI
  elif cur == EY or cur == EM:
    if   mask == AA: m = EA
    if   mask == P1: m = EP
    if   mask == HH: m = EH
    if   mask == VV: m = EV
    if   mask == II: m = MI
    if   mask == BH: m = EB
  elif cur == OU:
    if   mask == II: m = OI
  elif cur == P1:
    if   mask == P1: m = P2
  elif cur == P2:
    if   mask == P1: m = P3
  elif cur == P3:
    if   mask == P1: m = P4
  elif cur == GG:
    if   mask == RH: m = GR
  elif cur == S1:
    if   mask == S1: m = S2
  elif mask.cliff():
    if cur == II and mask == NS:
        m = IN
    elif cur.cliff():
      m = CliffMask(cur.ord xor mask.ord)
    else:
      m = mask

  editor.mask[o] = m
  editor.dirty = true
  #if m.hazard:
  #  editor.level.find_actors()

action:
  proc input_mask(editor: var Editor) =
    let mask = case editor.recent_input
    of GLFWKey.A : AA
    of GLFWKey.B : BH
    of GLFWKey.C : IC
    of GLFWKey.D : SD
    of GLFWKey.F : FL
    of GLFWKey.G : GG
    of GLFWKey.H : HH
    of GLFWKey.I : II
    of GLFWKey.J : JJ
    of GLFWKey.L : LL
    of GLFWKey.M : EM
    of GLFWKey.N : NS
    of GLFWKey.O : OU
    of GLFWKey.P : P1
    of GLFWKey.R : RH
    of GLFWKey.S : S1
    of GLFWKey.T : TU
    of GLFWKey.U : CU
    of GLFWKey.V : VV
    of GLFWKey.W : SW
    of GLFWKey.X : XX
    of GLFWKey.Y : EY
    else: return
    editor.set_mask mask

proc select_one*(editor: var Editor) =
  editor.selection.x = editor.row.int32
  editor.selection.y = editor.col.int32
  editor.selection.z = editor.row.int32
  editor.selection.w = editor.col.int32

action:
  proc do_select_one*(editor: var Editor) = editor.select_one()

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
        let o = editor.offset(i + drow, j + dcol)
        if editor.cursor_data:
          editor.data[o] = stamp.data[k]
        if editor.cursor_mask:
          editor.mask[o] = stamp.mask[k]
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

proc has_selection(editor: Editor): bool =
  result = editor.selection.x != editor.selection.z or editor.selection.y != editor.selection.w

proc cursor(editor: var Editor, drow, dcol: int) =
  editor.input = ""
  if editor.brush:
    if editor.has_selection():
      editor.brush_selection(editor.row + drow, editor.col + dcol)
    else:
      let cur_o = editor.offset()
      let next_o = editor.offset( editor.row+drow, editor.col+dcol )
      if 0 < next_o and next_o < editor.data.len:
        if editor.cursor_data:
          editor.data[ next_o ] = editor.data[ cur_o ]
        if editor.cursor_mask:
          editor.mask[ next_o ] = editor.mask[ cur_o ]
        editor.dirty = true

  editor.row += drow
  editor.col += dcol

  if editor.selection.xy == editor.selection.zw:
    editor.select_one()

proc select_more(editor: var Editor, drow, dcol: int) =
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

action:
  proc select_all*(editor: var Editor) =
    editor.brush = false
    let (x,y) = editor.level.find_first()
    let (z,w) = editor.level.find_last()
    editor.selection.x = x.int32 - 1
    editor.selection.y = y.int32 - 1
    editor.selection.z = z.int32 + 1
    editor.selection.w = w.int32 + 1

  proc select_none*(editor: var Editor) =
    editor.brush = false
    editor.select_one()

  proc toggle_brush*(editor: var Editor) =
    editor.brush = not editor.brush
    if editor.has_selection() and not editor.cursor_in_selection():
      editor.select_one()

proc delete_selection(editor: var Editor, data: var seq[float]) =
  for o in editor.selection_offsets:
    data[o] = 0

proc delete_selection(editor: var Editor, mask: var seq[CliffMask]) =
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

action:
  proc do_delete(editor: var Editor) =
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

  proc do_save(editor: var Editor) =
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

action:
  proc undo(editor: var Editor) = discard
  proc redo(editor: var Editor) = discard

proc copy_clipboard(editor: var Editor) =
  setClipboardString nil, editor.serialize_selection().cstring
  editor.cut = vec4i(0,0,0,0)

proc cut_clipboard(editor: var Editor) =
  editor.copy_clipboard()
  editor.cut = editor.selection

proc execute_cut(editor: var Editor) =
  editor.dirty = true
  if editor.cut != vec4i(0,0,0,0):
    for o in editor.cut_offsets:
      if editor.cursor_mask:
        editor.mask[o] = XX
      if editor.cursor_data:
        editor.data[o] = 0f
    editor.cut = vec4i(0,0,0,0)

proc paste_clipboard(editor: var Editor) =
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

proc copy_both(editor: var Editor) =
  editor.cursor_mask = true
  editor.cursor_data = true
  editor.stamp = editor.get_selection_stamp()
  editor.cut = vec4i(0,0,0,0)

proc cut_both(editor: var Editor) =
  editor.copy_both()
  editor.cut = editor.selection

proc paste_both(editor: var Editor) =
  editor.cursor_mask = true
  editor.cursor_data = true
  editor.execute_cut()
  editor.selection = vec4i( editor.row.int32, editor.col.int32, editor.row.int32 + editor.stamp.height.int32 - 1, editor.col.int32 + editor.stamp.width.int32 - 1)
  editor.put_selection_stamp(editor.stamp, 0, 0)
  editor.dirty = true

action:
  proc do_copy(editor: var Editor) =
    if editor.cursor_mask == true and editor.cursor_data == true:
      editor.copy_both()
    else:
      editor.copy_clipboard()

  proc do_cut*(editor: var Editor) =
    if editor.cursor_mask == true and editor.cursor_data == true:
      editor.cut_both()
    else:
      editor.cut_clipboard()

  proc do_paste*(editor: var Editor) =
    if editor.cursor_mask == true and editor.cursor_data == true:
      editor.paste_both()
    else:
      editor.paste_clipboard()

  proc go_back*(editor: var Editor) =
    if editor.brush:
      editor.brush = false
    elif editor.has_selection():
      editor.select_one()
    else:
      editor.leave()

  proc toggle_cursor(editor: var Editor) =
    editor.cursor_mask = not editor.cursor_mask
    editor.cursor_data = not editor.cursor_mask

  proc cursor_both(editor: var Editor) =
    editor.cursor_mask = true
    editor.cursor_data = true

  proc rotate_stamp(editor: var Editor) =
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
        s2.mask.add s1.mask[o1].rotate()
    editor.stamp = s2

  proc flip_stamp(editor: var Editor) =
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

  proc reverse_stamp(editor: var Editor) =
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

  proc select_up(editor: var Editor)         = editor.select_more(-1, 0)
  proc select_down(editor: var Editor)       = editor.select_more(+1, 0)
  proc select_left(editor: var Editor)       = editor.select_more( 0,-1)
  proc select_right(editor: var Editor)      = editor.select_more( 0,+1)
  proc select_diag_up(editor: var Editor)    = editor.select_more(-1,-1)
  proc select_diag_down(editor: var Editor)  = editor.select_more(+1,+1)
  proc select_diag_left(editor: var Editor)  = editor.select_more(+1,-1)
  proc select_diag_right(editor: var Editor) = editor.select_more(-1,+1)

  proc cursor_up(editor: var Editor)         = editor.cursor(-1, 0)
  proc cursor_down(editor: var Editor)       = editor.cursor(+1, 0)
  proc cursor_left(editor: var Editor)       = editor.cursor( 0,-1)
  proc cursor_right(editor: var Editor)      = editor.cursor( 0,+1)
  proc cursor_diag_up(editor: var Editor)    = editor.cursor(-1,-1)
  proc cursor_diag_down(editor: var Editor)  = editor.cursor(+1,+1)
  proc cursor_diag_left(editor: var Editor)  = editor.cursor(+1,-1)
  proc cursor_diag_right(editor: var Editor) = editor.cursor(-1,+1)

let editor_keymap_command* = {
  GLFWKey.Y          : redo              ,
  GLFWKey.A          : select_all        ,
  GLFWKey.D          : select_none       ,
  GLFWKey.S          : do_save           ,
  GLFWKey.Z          : undo              ,
  GLFWKey.X          : do_cut            ,
  GLFWKey.C          : do_copy           ,
  GLFWKey.V          : do_paste          ,
}.toOrderedTable

let editor_keymap_shift* = {
  GLFWKey.Tab        : cursor_both       ,
  GLFWKey.Minus      : flip_stamp        ,
  GLFWKey.Backslash  : reverse_stamp     ,
  GLFWKey.Up         : select_up         ,
  GLFWKey.Down       : select_down       ,
  GLFWKey.Left       : select_left       ,
  GLFWKey.Right      : select_right      ,
  GLFWKey.PageUp     : select_diag_up    ,
  GLFWKey.PageDown   : select_diag_down  ,
  GLFWKey.Home       : select_diag_left  ,
  GLFWKey.End        : select_diag_right ,
}.toOrderedTable

let editor_keymap* = {
  GLFWKey.Up         : cursor_up         ,
  GLFWKey.Down       : cursor_down       ,
  GLFWKey.Left       : cursor_left       ,
  GLFWKey.Right      : cursor_right      ,
  GLFWKey.PageUp     : cursor_diag_up    ,
  GLFWKey.PageDown   : cursor_diag_down  ,
  GLFWKey.Home       : cursor_diag_left  ,
  GLFWKey.End        : cursor_diag_right ,
  GLFWKey.Minus      : do_dec            ,
  GLFWKey.KpSubtract : do_dec            ,
  GLFWKey.Equal      : do_inc            ,
  GLFWKey.KpAdd      : do_inc            ,
  GLFWKey.K0         : input_number      ,
  GLFWKey.K1         : input_number      ,
  GLFWKey.K2         : input_number      ,
  GLFWKey.K3         : input_number      ,
  GLFWKey.K4         : input_number      ,
  GLFWKey.K5         : input_number      ,
  GLFWKey.K6         : input_number      ,
  GLFWKey.K7         : input_number      ,
  GLFWKey.K8         : input_number      ,
  GLFWKey.K9         : input_number      ,
  GLFWKey.Period     : input_decimal     ,
  GLFWKey.KpDecimal  : input_decimal     ,
  GLFWKey.A          : input_mask        ,
  GLFWKey.B          : input_mask        ,
  GLFWKey.C          : input_mask        ,
  GLFWKey.F          : input_mask        ,
  GLFWKey.G          : input_mask        ,
  GLFWKey.H          : input_mask        ,
  GLFWKey.I          : input_mask        ,
  GLFWKey.J          : input_mask        ,
  GLFWKey.L          : input_mask        ,
  GLFWKey.M          : input_mask        ,
  GLFWKey.N          : input_mask        ,
  GLFWKey.P          : input_mask        ,
  GLFWKey.S          : input_mask        ,
  GLFWKey.T          : input_mask        ,
  GLFWKey.R          : input_mask        ,
  GLFWKey.O          : input_mask        ,
  GLFWKey.U          : input_mask        ,
  GLFWKey.V          : input_mask        ,
  GLFWKey.W          : input_mask        ,
  GLFWKey.X          : input_mask        ,
  GLFWKey.Y          : input_mask        ,
  GLFWKey.Backspace  : do_delete         ,
  GLFWKey.Delete     : do_delete         ,
  GLFWKey.Space      : toggle_brush      ,
  GLFWKey.Tab        : toggle_cursor     ,
  GLFWKey.Slash      : rotate_stamp      ,
  GLFWKey.E          : do_leave          ,
  GLFWKey.Escape     : go_back           ,
}.toOrderedTable

proc handle_key*(editor: var Editor, key: int32, mods: int32): bool =
  #let io = igGetIO()
  #if not io.wantCaptureMouse:
  #  return

  template handler(map) =
    if map.hasKey(key):
      map[key].callback(editor)
    else:
      result = false

  result = true
  if (mods and GLFWModControl) != 0 or (mods and GLFWModSuper) != 0:
    handler(editor_keymap_command)
  elif (mods and GLFWModShift) != 0:
    handler(editor_keymap_shift)
  else:
    editor.recent_input = key
    handler(editor_keymap)

  if editor.dirty:
    for i in -1 .. 1:
      for j in -1 .. 1:
        editor.level.calculate_vbos(editor.row + i, editor.col + j)
    if editor.has_selection():
      editor.update_selection_vbos()
    editor.level.update_vbos()
    editor.dirty = false

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

  proc draw_mask_cell(m: CliffMask, enabled: bool = true) =
    var txt = if m.cliff():
      mask_chars[m] #mask_chars[($m)[0]] & mask_chars[($m)[1]]
    else: $m
    if txt.len < 2: txt = " " & txt
    var text = txt.cstring

    #const period = 10
    #let hmod = 0.6 + 0.1 * sin( 2 * 3.14159265 * (h mod period).float / period.float )
    #color.value = ImVec4(x: 0.8, y: 0.8, z: 0.8, w: 1.0)
    color.value = ImVec4(x: 1.0, y: 1.0, z: 1.0, w: 1.0)
    if m == XX: color.value = dark_color
    if not enabled:
      color.value = ImVec4(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
    igTextColored(color.value, text)

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


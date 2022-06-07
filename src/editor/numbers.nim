
proc get_data(editor: Editor): float =
  let o = editor.offset()
  return editor.data[o]

proc set_data(editor: var Editor, value: float) =
  editor.level[editor.row, editor.col] = value
  editor.dirty.add (editor.row, editor.col)

proc inc_dec(editor: var Editor, d: float) =
  if editor.cursor_in_selection():
    for i,j in editor.selection_coords():
      let h = editor.level.map[i,j].height
      if h == 0: continue
      var value = h + d
      if d == 1:
        value = value.int.float
      editor.level[i,j] = value
      editor.dirty.add (i,j)
    editor.update_selection_vbos()
    editor.update_selector()
  else:
    let h = editor.get_data()
    if h == 0:
      return
    var value = h + d
    if d == 1:
      value = value.int.float
    editor.set_data (h + d).int.float
    editor.dirty.add (editor.row, editor.col)

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


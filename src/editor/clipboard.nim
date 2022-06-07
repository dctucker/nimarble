
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
  editor.stamp = editor.get_selection_stamp()
  setClipboardString nil, editor.serialize_selection().cstring
  editor.cut = vec4i(0,0,0,0)

proc cut_clipboard(editor: var Editor) =
  editor.stamp = editor.get_selection_stamp()
  editor.copy_clipboard()
  editor.cut = editor.selection

proc execute_cut(editor: var Editor) =
  if editor.cut != vec4i(0,0,0,0):
    for i,j in editor.cut_coords:
      if editor.cursor_mask:
        editor.level[i,j] = XX
      if editor.cursor_data:
        editor.level[i,j] = 0f
      editor.dirty.add (i,j)
    editor.cut = vec4i(0,0,0,0)

proc paste_clipboard(editor: var Editor) =
  editor.execute_cut()
  editor.selection = vec4i( editor.row.int32, editor.col.int32, editor.row.int32 + editor.stamp.height.int32 - 1, editor.col.int32 + editor.stamp.width.int32 - 1)
  let clip = $getClipboardString(nil)
  var i = editor.row
  for line in clip.split("\n"):
    var j = editor.col
    for value in line.split("\t"):
      if editor.cursor_mask:
        editor.level[i,j] = editor.level.parseMask(value)
      if editor.cursor_data:
        editor.level[i,j] = editor.level.parseFloat(value)
      editor.dirty.add (i,j)
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

action:
  proc do_copy(editor: var Editor) =
    editor.stamp = editor.get_selection_stamp()
    editor.cut = vec4i(0,0,0,0)

  proc do_cut*(editor: var Editor) =
    editor.copy_both()
    editor.cut = editor.selection

  proc do_paste*(editor: var Editor) =
    editor.execute_cut()
    editor.selection = vec4i( editor.row.int32, editor.col.int32, editor.row.int32 + editor.stamp.height.int32 - 1, editor.col.int32 + editor.stamp.width.int32 - 1)
    editor.put_selection_stamp(editor.stamp, 0, 0)


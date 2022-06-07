
proc move_cursor(editor: var Editor, drow, dcol: int) =
  editor.input = ""
  if editor.brush:
    if editor.has_selection():
      editor.brush_selection(editor.row + drow, editor.col + dcol)
    else:
      let cur_o = editor.offset()
      let next_o = editor.offset( editor.row+drow, editor.col+dcol )
      if 0 < next_o and next_o < editor.data.len:
        if editor.cursor_data:
          editor.level[editor.row + drow, editor.col + dcol] = editor.data[ cur_o ]
        if editor.cursor_mask:
          editor.level[editor.row + drow, editor.col + dcol] = editor.mask[ cur_o ]
        editor.dirty.add (editor.row + drow, editor.col + dcol)

  editor.row += drow
  editor.col += dcol

  if editor.selection.xy == editor.selection.zw:
    editor.select_one()

action:
  proc do_delete(editor: var Editor) =
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
    editor.level[editor.row, editor.col] = 0
    editor.dirty.add (editor.row, editor.col)

  proc toggle_cursor(editor: var Editor) =
    editor.cursor_mask = not editor.cursor_mask
    editor.cursor_data = not editor.cursor_mask

  proc cursor_both(editor: var Editor) =
    editor.cursor_mask = true
    editor.cursor_data = true


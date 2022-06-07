
action:
  proc select_up(editor: var Editor)         = editor.select_more(-1, 0)
  proc select_down(editor: var Editor)       = editor.select_more(+1, 0)
  proc select_left(editor: var Editor)       = editor.select_more( 0,-1)
  proc select_right(editor: var Editor)      = editor.select_more( 0,+1)
  proc select_diag_up(editor: var Editor)    = editor.select_more(-1,-1)
  proc select_diag_down(editor: var Editor)  = editor.select_more(+1,+1)
  proc select_diag_left(editor: var Editor)  = editor.select_more(+1,-1)
  proc select_diag_right(editor: var Editor) = editor.select_more(-1,+1)

  proc cursor_up(editor: var Editor)         = editor.move_cursor(-1, 0)
  proc cursor_down(editor: var Editor)       = editor.move_cursor(+1, 0)
  proc cursor_left(editor: var Editor)       = editor.move_cursor( 0,-1)
  proc cursor_right(editor: var Editor)      = editor.move_cursor( 0,+1)
  proc cursor_diag_up(editor: var Editor)    = editor.move_cursor(-1,-1)
  proc cursor_diag_down(editor: var Editor)  = editor.move_cursor(+1,+1)
  proc cursor_diag_left(editor: var Editor)  = editor.move_cursor(+1,-1)
  proc cursor_diag_right(editor: var Editor) = editor.move_cursor(-1,+1)

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
  GLFWKey.D          : input_mask        ,
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

  if editor.dirty.len > 0:
    for i in -1 .. 1:
      for j in -1 .. 1:
        editor.dirty.add (editor.row + i, editor.col + j)
    if editor.has_selection():
      editor.update_selection_vbos()
      editor.update_selector()
    editor.update_dirty_vbos()
    editor.level.update_vbos()


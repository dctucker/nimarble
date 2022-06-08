
proc offset[T: Ordinal](editor: Editor, row, col: T): int =
  result = editor.level.offset( row, col ).int

proc offset(editor: Editor): int =
  result = editor.offset( editor.row, editor.col )

iterator coords(editor: Editor, rect: Vec4i): (int,int) =
  for i in rect.x .. rect.z:
    for j in rect.y .. rect.w:
      yield (i.int, j.int)

iterator offsets(editor: Editor, rect: Vec4i): int =
  for i,j in editor.coords(rect):
    yield editor.offset(i,j)

#iterator offsets(editor: Editor): int =
#  #let all = vec4i( x: 0, y: 0, z: editor.level.height - 1, w: editor.level.width - 1)
#  let all = vec4i( 0.int32, 0.int32, editor.level.height.int32 - 1, editor.level.width.int32 - 1)
#  for o in editor.offsets(all): yield o

iterator selection_coords(editor: Editor): (int,int) =
  for i,j in editor.coords(editor.selection): yield (i,j)
iterator cut_coords(editor: Editor): (int,int) =
  for i,j in editor.coords(editor.cut): yield (i,j)

iterator selection_offsets(editor: Editor): int =
  for o in editor.offsets(editor.selection): yield o
#iterator cut_offsets(editor: Editor): int =
#  for o in editor.offsets(editor.cut): yield o

proc invalidate[T:Ordinal](editor: var Editor, i,j: T) =
  add(editor.dirty, (i.int,j.int))



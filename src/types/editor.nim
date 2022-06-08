
type
  Stamp* = object
    width*, height*: int
    data*: seq[float]
    mask*: seq[CliffMask]

  Cursor* = ref object
    mesh*: Mesh
    cube*: seq[CubePoint]
    phase*: int

  Selector* = ref object
    mesh*: Mesh

  Editor* = ref object
    visible*: bool
    level*: Level
    name*: string
    row*, col*: int
    selection*: Vec4i
    cut*: Vec4i
    width*: int
    height*: int
    focused*: bool
    input*: string
    cursor_mask*: bool
    cursor_data*: bool
    cursor*: Cursor
    selector*: Selector
    brush*: bool
    dirty*: seq[(int,int)]
    stamp*: Stamp
    recent_input*: GLFWKey

proc data*(editor: Editor): var seq[float]     = editor.level.data
proc mask*(editor: Editor): var seq[CliffMask] = editor.level.mask


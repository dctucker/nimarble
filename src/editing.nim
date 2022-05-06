from nimgl/glfw import GLFWKey
import nimgl/imgui
import glm

import types

const highlight_width = 16
const line_height = 16
const dark_color = ImVec4(x: 0.2, y: 0.2, z: 0.2, w: 1.0)

proc inc(editor: Editor) =
  let o = editor.level.offset(editor.row, editor.col)
  let h = editor.level.data[o]
  editor.level.data[o] = (h + 1).int.float

proc dec(editor: Editor) =
  let o = editor.level.offset(editor.row, editor.col)
  let h = editor.level.data[o]
  editor.level.data[o] = (h - 1).int.float

proc handle_key*(editor: Editor, key: int32): bool =
  #let io = igGetIO()
  #if not io.wantCaptureMouse:
  #  return

  result = true
  case key
  of GLFWKey.E:
    editor.focused = false
    igFocusWindow(nil)

  of GLFWKey.Up:
    editor.row.dec
  of GLFWKey.Down:
    editor.row.inc
  of GLFWKey.Left:
    editor.col.dec
  of GLFWKey.Right:
    editor.col.inc
  of GLFWKey.Minus, GLFWKey.KpSubtract:
    editor.dec
  of GLFWKey.Equal, GLFWKey.KpAdd:
    editor.inc
  else:
    result = false

proc draw*(editor: Editor) =
  igSetNextWindowSizeConstraints ImVec2(x:300, y:300), ImVec2(x: 1000, y: 1000)
  igBegin("editor")
  var level = editor.level
  if level == nil: return
  var style = igGetStyle()
  let highlight_color = style.colors[ImGuiCol.TextSelectedBg.int32].igGetColorU32

  igSameLine()

  var color: ImColor
  var draw_list = igGetWindowDrawList()

  proc draw_cursor =
    var pos: ImVec2
    igGetCursorScreenPosNonUDT(pos.addr)
    draw_list.addRectFilled pos, ImVec2(x: pos.x + highlight_width, y: pos.y + line_height), highlight_color

  for i in editor.row - 5 .. editor.row + 5:
    for j in editor.col - 5 .. editor.col + 5:
      igSameLine()

      if i == editor.row and j == editor.col:
        draw_cursor()

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
    igText(" | ")

    for j in editor.col - 5 .. editor.col + 5:
      igSameLine()

      if i == editor.row and j == editor.col:
        draw_cursor()

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


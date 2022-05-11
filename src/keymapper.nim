import std/tables
import nimgl/imgui

from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper
import types

proc draw_keymap*[T](map: Table[GLFWKey, T]) =
  igBegin("keymap")
  for key in map.keys:
    igText($key)
    igSameLine()
    igText($map[key].repr)
  igEnd()

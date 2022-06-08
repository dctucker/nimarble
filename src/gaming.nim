import std/random
randomize()

from nimgl/glfw import setInputMode, setCursorPos, GLFW_CURSOR_SPECIAL, GLFW_CURSOR_NORMAL, GLFWCursorDisabled, setWindowShouldClose
import glm
import nimgl/opengl

import masks
import types
import wrapper
import window
import models
import scene
import shaders
from leveldata import get_level, sky, load_level, slope
from editing import focus, leave
from keymapper import action

const level_squash* = 0.5f
var start_level*: int32 = 1

var app* = Application(selected_level: -1) # ugh, this needs to be moved out
var editor*: Editor

proc coord*(player: Player): var Vec3f {.inline.} = return player.mesh.pos

include game/[
  input     ,
  view      ,
  models    ,
  animation ,
  actions   ,
]


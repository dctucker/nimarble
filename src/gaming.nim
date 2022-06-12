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

proc newGame*: Game =
  Game(
    state: ATTRACT,
    level_number: 1,
    player: Player(),
    light: newLight(
      pos            = vec3f( -25, 116, 126 ),
      color          = vec3f(0.665, 0.665, 0.665),
      specular       = vec3f(0.426, 0.479, 0.468),
      ambient        = 0.75,
      power          = 22500f,
    ),
    camera: Camera(
      fov: 30f,
      distance: 30f,
    ),
    paused : false,
    mouse_mode : MouseAcc,
    following : true,
    frame_step : false,
    goal : false,
    wireframe : false,
  )


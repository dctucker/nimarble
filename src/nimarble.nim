{. warning[HoleEnumConv]:off .}

#import nimprof
import std/tables
import nimgl/[glfw,opengl]
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
import glm
import wrapper

import pieces
import types
import masks
import models
import leveldata
import editing
import scene
import gaming
import window
import keymapper

var game: Game
var t  = 0.0f
var dt = 0.0f
var time = 0.0f
var event_time = 0.0f
var fps_start = 0f
var fps_frames = 0
var frame_time = 0f

proc fps_count =
  inc fps_frames
  frame_time = (dt / fps_frames.float) * 1000
  fps_frames = 0
  fps_start = t
  logs.frame_time.log frame_time

include runtime/[
  input,
  setup,
  physics,
  render,
  player,
  ui,
  main,
]

#start_level = 5.int32
when isMainModule:
  main()

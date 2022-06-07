{. warning[HoleEnumConv]:off .}

import std/tables
import strutils
import glm
import math
import nimgl/glfw
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
#import zippy
from scene import Camera, Light, pos, vel, acc
import types
from leveldata import sky, wave_height, xlat_coord, has_coord, cube_point, calculate_vbos, update_vbos
import masks
import assets
import models

#import pixie

var width*, height*: int32
var aspect*: float32

width = 1600
height = 1200
aspect = width / height

var mouse*: Vec3f
var joystick* = Joystick()


proc middle*(): Vec2f {.inline.} = vec2f(width.float * 0.5f, height.float * 0.5f)

var ig_context*: ptr ImGuiContext

include windows/fonts

proc setup_imgui*(w: GLFWWindow) =
  ig_context = igCreateContext()
  doAssert igGlfwInitForOpenGL(w, true)
  doAssert igOpenGL3Init()
  igStyleColorsDark()
  setup_fonts()
  igSetNextWindowPos(ImVec2(x:5, y:5))

proc display_size*(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)

include windows/stats
include windows/game
include windows/camera
include windows/light
include windows/pieces
include windows/masks
include windows/cube
include windows/joystick
include windows/menu


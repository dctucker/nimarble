{. warning[HoleEnumConv]:off .}

import glm
import nimgl/glfw
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
#import zippy
from scene import Camera, Light, pos, vel, acc
from types import Actor
from leveldata import sky

const terminus_ttf_asset = staticRead("../assets/fonts/TerminusTTF.ttf")
const terminus_ttf_len = terminus_ttf_asset.len
var terminus_ttf = terminus_ttf_asset.cstring

#[
const terminus_ttf_gz_asset = staticRead("../assets/fonts/TerminusTTF.ttf.gz")
var terminus_ttf_gz = terminus_ttf_gz_asset.uncompress
var terminus_ttf_gz_len = terminus_ttf_gz.len
var terminus_ttf = terminus_ttf_gz_asset.cstring
]#

var width*, height*: int32
var aspect*: float32

width = 1600
height = 1200
aspect = width / height

var mouse*: Vec3f

proc middle*(): Vec2f = vec2f(width.float * 0.5f, height.float * 0.5f)

var ig_context*: ptr ImGuiContext
var small_font*: ptr ImFont
var large_font*: ptr ImFont

proc setup_imgui*(w: GLFWWindow) =
  ig_context = igCreateContext()
  #var io = igGetIO()
  #io.configFlags = NoMouseCursorChange
  doAssert igGlfwInitForOpenGL(w, true)
  doAssert igOpenGL3Init()
  igStyleColorsDark()
  var atlas = ig_context.io.fonts
  var ranges = @[ 0x1.ImWchar, 0x3000.ImWchar, 0.ImWchar ]

  small_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len.int32, 14, nil, ranges[0].addr)
  large_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len.int32, 36)
  igSetNextWindowPos(ImVec2(x:5, y:5))

proc display_size*(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)

proc draw_goal* =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 150, y:mid.y))
  igSetNextWindowSize(ImVec2(x:300f, y:48))
  if igBegin("GOAL", nil, ImGuiWindowFlags.NoDecoration):
    igPushFont( large_font )
    igText("Level complete!")
    igPopFont()
  igEnd()

proc draw_clock*[T](clock: T) =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 28, y: 0))
  igSetNextWindowSize(ImVec2(x:56, y:48))
  if igBegin("CLOCK", nil, ImGuiWindowFlags(171)):
    igPushFont( large_font )
    let clk_value = 60 - (clock / 100)
    var clk = $clk_value.int
    if clk.len < 2: clk = "0" & clk
    var cclk = clk.cstring
    igTextColored ImVec4(x:0.5,y:0.1,z:0.1, w:1.0), cclk
    igPopFont()
  igEnd()

proc info_window*(camera: var Camera): bool =
  var dirty = false
  #igSetNextWindowPos(ImVec2(x:5, y:500))
  if igBegin("camera"):
    dirty = igDragFloat3("pos"       , camera.pos.arr          , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("target"    , camera.target.arr       , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("up"        , camera.up.arr           , 0.125, -sky, sky  ) or dirty
    igSeparator()
    dirty = igDragFloat3("pan.target", camera.pan.target.arr   , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("pan"       , camera.pan.pos.arr      , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("pan_vel"   , camera.pan.vel.arr      , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("pan_acc"   , camera.pan.acc.arr      , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat( "fov"       , camera.fov.addr         , 0.125,   0f, 360f ) or dirty
  igEnd()
  result = dirty

proc info_window*(light: var Light): bool =
  var dirty = false
  if igBegin("light"):
    dirty = igDragFloat3("pos"       , light.pos.data.arr      , 0.125, -sky, +sky  ) or dirty
    dirty = igColorEdit3("color"     , light.color.data.arr                         ) or dirty
    dirty = igDragFloat( "power"     , light.power.data.addr   , 100f, 0f, 900000f  ) or dirty
    dirty = igDragFloat( "ambient"   , light.ambient.data.addr , 0.125, 0f, 1f      ) or dirty
    dirty = igColorEdit3("specular"  , light.specular.data.arr                      ) or dirty
  igEnd()
  result = dirty

proc info_window*(actors: seq[Actor]) =
  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("actors")
  if actors.len > 0:
    for a in actors.low .. actors.high:
      var actor = actors[a]
      let name = cstring("actor " & $a & " pos")
      igDragFloat3 name, actors[a].mesh.pos.arr, 0.125, -sky, sky
  igEnd()


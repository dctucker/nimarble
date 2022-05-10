{. warning[HoleEnumConv]:off .}

import glm
import nimgl/glfw
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
import zippy

const terminus_ttf_asset = staticRead("../assets/fonts/TerminusTTF.ttf.gz")
var terminus_ttf = uncompress(terminus_ttf_asset).cstring

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
  small_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_asset.len.int32, 14)
  large_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_asset.len.int32, 36)
  igSetNextWindowPos(ImVec2(x:5, y:5))

proc draw_goal* =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 150, y:mid.y))
  igSetNextWindowSize(ImVec2(x:300f, y:48))
  igPushFont( large_font )
  igBegin("GOAL", nil, ImGuiWindowFlags.NoDecoration)
  igText("Level complete!")
  igPopFont()
  igEnd()

proc draw_clock*[T](clock: T) =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 28, y: 0))
  igSetNextWindowSize(ImVec2(x:56, y:48))
  igPushFont( large_font )
  igBegin("CLOCK", nil, ImGuiWindowFlags(171))
  let clk_value = 60 - (clock / 100)
  var clk = $clk_value.int
  if clk.len < 2: clk = "0" & clk
  var cclk = clk.cstring
  igTextColored ImVec4(x:0.5,y:0.1,z:0.1, w:1.0), cclk
  igEnd()
  igPopFont()

proc display_size*(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)


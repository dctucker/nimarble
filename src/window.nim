{. warning[HoleEnumConv]:off .}

import strutils
import glm
import nimgl/glfw
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
#import zippy
from scene import Camera, Light, pos, vel, acc
from types import Application, Joystick, JoyButtons, Actor, Fixture, CliffMask, name
from leveldata import sky

import pixie

#import assetfile

var width*, height*: int32
var aspect*: float32

width = 1600
height = 1200
aspect = width / height

var mouse*: Vec3f
var joystick* = Joystick()


proc middle*(): Vec2f = vec2f(width.float * 0.5f, height.float * 0.5f)

var ig_context*: ptr ImGuiContext
var small_font*: ptr ImFont
var large_font*: ptr ImFont

#var texture = newSeq[uint8](512*512)

proc setup_fonts =
  const terminus_fn = "assets/fonts/TerminusTTF.ttf"
  const terminus_ttf_asset = staticRead("../" & terminus_fn)
  #var terminus_ttf_asset = assetfile.getAsset(terminus_fn)
  let terminus_ttf_len = terminus_ttf_asset.len.int32
  echo "Font loaded (", terminus_ttf_len, " bytes)"
  var terminus_ttf = terminus_ttf_asset.cstring # [0].addr

  var atlas = igGetIO().fonts
  #atlas.addFontDefault()
  var ranges = @[ 0x1.ImWchar, 0x7f.ImWchar,
    0x2500.ImWchar, 0x2600.ImWchar,
    0.ImWchar
  ]

  small_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len, 14, nil, ranges[0].addr)
  #small_font.
  #small_font = atlas.addFontFromFileTTF(terminus_fn, 14, nil, ranges[0].addr)
  #assert small_font != nil
  #assert small_font.isLoaded()
  large_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len, 36, nil, ranges[0].addr)
  #large_font = atlas.addFontFromFileTTF(terminus_fn, 36)
  #assert large_font != nil
  #assert large_font.isLoaded()
  atlas.build()

  var tex_pixels: ptr[char]
  var tex_width, tex_height: int32
  atlas.getTexDataAsRGBA32(tex_pixels.addr, tex_width.addr, tex_height.addr)
  echo "Atlas texture: ", tex_width, "x", tex_height
  let pixels = cast[ptr UncheckedArray[char]](tex_pixels)

  var image = newImage(tex_width, tex_height)
  for i in 0..tex_height:
    for j in 0..tex_width:
      image[j,i] = color(
        pixels[4*i*tex_width + 4*j + 0].float / 255f,
        pixels[4*i*tex_width + 4*j + 1].float / 255f,
        pixels[4*i*tex_width + 4*j + 2].float / 255f,
        pixels[4*i*tex_width + 4*j + 3].float / 255f,
      )
  image.writeFile("assets/texture.png")

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

proc draw_goal* =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 150, y:mid.y))
  igSetNextWindowSize(ImVec2(x:300f, y:48))
  if igBegin("GOAL", nil, ImGuiWindowFlags.NoDecoration):
    igPushFont( large_font )
    igText("Level complete!")
    igPopFont()
  igEnd()

const frame_times_len = 256
var frame_times = newSeq[float](frame_times_len)
var frame_times_phase: int32 = 0
proc get_frame_time(data: pointer, index: int32): float32 {.cdecl, varargs.} =
  return frame_times[index]

proc log_frame_time*(frame_time: float) =
  frame_times[frame_times_phase] = frame_time
  frame_times_phase.inc
  if frame_times_phase >= frame_times_len:
    frame_times_phase = 0

proc draw_stats*[T](value: T) =
  #igSetNextWindowPos(ImVec2(x: (width - 112).float32, y: 0))
  #igSetNextWindowSize(ImVec2(x:112, y:48))

  if igBegin("stats", nil, ImGuiWindowFlags(171)):
    #igPushFont( large_font )
    let clk = frame_times.max().formatFloat(ffDecimal, 3) & " ms"
    var cclk = clk.cstring
    #igTextColored ImVec4(x:0.5,y:0.1,z:0.1, w:1.0), cclk

    igPlotEx(
      ImGuiPlotType.Lines,
      "frame time",
      get_frame_time,
      frame_times.addr,
      frame_times_len,
      frame_times_phase,
      cclk,
      4f,
      64f,
      ImVec2(x: 256, y: 100),
    )
    #igPopFont()
  igEnd()

proc draw_clock*[T](clock: T) =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 200, y: 0))
  igSetNextWindowSize(ImVec2(x:200, y:48))
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

proc info_window*(fixtures: seq[Fixture]) =
  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("fixtures")
  if fixtures.len > 0:
    for f in fixtures.low .. fixtures.high:
      var fixture = fixtures[f]
      let name = cstring("fixture " & $f & " pos")
      igDragFloat3 name   , fixtures[f].mesh.pos.arr, 0.125, -sky, sky
      let rotname = cstring("fixture " & $f & " rot")
      igDragFloat4 rotname, fixtures[f].mesh.rot.arr, 1f.radians, -180f.radians, 180f.radians
  igEnd()

proc info_window*(mask: CliffMask) =
  var b: bool
  if igBegin("masks", b.addr, NoFocusOnAppearing):
    if igBeginTable("keymap", 2):
      for m in CliffMask.low .. CliffMask.high:
        igTableNextRow()

        let sym = ($m).cstring
        #let ico = $m.cstring
        let name = m.name().cstring
        igTableSetColumnIndex(0)
        igText(sym)
        igTableSetColumnIndex(1)
        igText(name)

    igEndTable()
  igEnd()

proc info_window*(joystick: var Joystick) =
  if igBegin("joystick"):
    let size = ImVec2(x: 16, y: 64)
    igSliderFloat  "left thumb x"  ,        joystick.left_thumb.x.addr  , -1,  1
    igVSliderFloat "left thumb y"  , size , joystick.left_thumb.y.addr  ,  1, -1
    igSliderFloat  "right thumb x" ,        joystick.right_thumb.x.addr , -1,  1
    igVSliderFloat "right thumb y" , size , joystick.right_thumb.y.addr ,  1, -1
    igSliderFloat2 "triggers"      ,        joystick.triggers.arr       , -1,  1
    igCheckbox     "x"             ,        joystick.buttons.x.addr
    igCheckbox     "y"             ,        joystick.buttons.y.addr
    igCheckbox     "a"             ,        joystick.buttons.a.addr
    igCheckbox     "b"             ,        joystick.buttons.b.addr
    igCheckbox     "up"            ,        joystick.buttons.up.addr
    igCheckbox     "down"          ,        joystick.buttons.down.addr
    igCheckbox     "left"          ,        joystick.buttons.left.addr
    igCheckbox     "right"         ,        joystick.buttons.right.addr
    igCheckbox     "xbox"          ,        joystick.buttons.xbox.addr
    igCheckbox     "start"         ,        joystick.buttons.start.addr
    igCheckbox     "lthumb"        ,        joystick.buttons.lthumb.addr
    igCheckbox     "rthumb"        ,        joystick.buttons.rthumb.addr
    igCheckbox     "lb"            ,        joystick.buttons.lb.addr
    igCheckbox     "rb"            ,        joystick.buttons.rb.addr
  igEnd()

proc main_menu*(app: Application) =
  igSetNextWindowPos  ImVec2(x:0.float32, y:0.float32)
  igSetNextWindowSize ImVec2(x:width.float32, y: 50.float32)
  var b = false
  #if igBegin("toolbox"): #, b.addr, NoDecoration or MenuBar or Popup):
  assert igGetCurrentContext() != nil
  if igBeginMainMenuBar():
    if igBeginMenu("Level"):
      igMenuItem("1")
      igMenuItem("2")
      igMenuItem("3")
      igMenuItem("4")
      igMenuItem("5")
      igMenuItem("6")
      igEndMenu()
    if igBeginMenu("Windows"):
      igMenuItem "Player"      , nil, app.show_player.addr
      igMenuItem "Light"       , nil, app.show_light.addr
      igMenuItem "Camera"      , nil, app.show_camera.addr
      igMenuItem "Actors"      , nil, app.show_actors.addr
      igMenuItem "Fixtures"    , nil, app.show_fixtures.addr
      igMenuItem "Cube Points" , nil, app.show_cube_points.addr
      igMenuItem "Editor"      , "E", app.show_editor.addr
      igMenuItem "Keymap"      , "?", app.show_keymap.addr
      igMenuItem "Joystick"    , "J", app.show_joystick.addr
      igMenuItem "Metrics"     , nil, app.show_metrics.addr
      igMenuItem "Masks"       , nil, app.show_masks.addr
      igEndMenu()
    discard
  igEndMainMenuBar()


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
from types import Application, Joystick, JoyButtons, Actor, ActorSet, Fixture, Piece
from leveldata import sky, wave_height
import masks
import assets

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
var small_font*: ptr ImFont
var large_font*: ptr ImFont

#var texture = newSeq[uint8](512*512)

proc add_custom_glyph(atlas: ptr ImFontAtlas, rect_id: int32) =
  var tex_pixels: ptr[char]
  var tex_width, tex_height: int32
  atlas.getTexDataAsRGBA32(tex_pixels.addr, tex_width.addr, tex_height.addr)
  let pixels = cast[ptr UncheckedArray[uint8]](tex_pixels)
  #echo "Atlas texture: ", tex_width, "x", tex_height

  let rect = atlas.getCustomRectByIndex(rect_id)
  var c = 0x00
  const half = 7
  for i in 0 ..< rect.height.int32:
    for j in 0 ..< rect.width.int32:
      case j
      of 6: c = 0xe0
      else: c = 0xff

      case i
      of 0        : c = 0x95
      of half - 1 : c = 0xcf
      of half     : c = 0x66
      of half + 1 : c = 0xbe
      of 14       : c = 0x8d
      else        : discard

      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 0] = c.uint8
      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 1] = c.uint8
      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 2] = c.uint8
      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 3] = c.uint8

  #[
  var image = newImage(tex_width, tex_height)
  for i in 0 ..< tex_height:
    for j in 0 ..< tex_width:
      image[j,i] = color(
        pixels[4*i*tex_width + 4*j + 0].float / 255f,
        pixels[4*i*tex_width + 4*j + 1].float / 255f,
        pixels[4*i*tex_width + 4*j + 2].float / 255f,
        pixels[4*i*tex_width + 4*j + 3].float / 255f,
      )
  image.writeFile("assets/texture.png")
  ]#

#import std/unicode
#for rune in glyphs.runes:
#  echo rune.ord.toHex()

proc setup_fonts =
  var atlas = igGetIO().fonts

  const ascii = @[ 0x1.ImWchar, 0x7f.ImWchar ]
  const blocks = @[
    0x2264.ImWchar, 0x2265.ImWchar,
    0x2580.ImWchar, 0x2580.ImWchar,
    0x2584.ImWchar, 0x2584.ImWchar,
    0x2588.ImWchar, 0x2588.ImWchar,
    0x258C.ImWchar, 0x258C.ImWchar,
    0x2590.ImWchar, 0x2590.ImWchar,
    0x2599.ImWchar, 0x2599.ImWchar,
    0x259B.ImWchar, 0x259C.ImWchar,
    0x259F.ImWchar, 0x259F.ImWchar,
    0x25A0.ImWchar, 0x25A0.ImWchar,
  ]
  const imwnull = @[0.ImWchar]
  var ascii_ranges = ascii          & imwnull
  var full_ranges  = ascii & blocks & imwnull

  small_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len, 14, nil, full_ranges[0].addr)
  let rect_id = atlas.addCustomRectFontGlyph(small_font, 0x25a0.ImWchar, 7, 15, 6+1)

  #small_font.
  #small_font = atlas.addFontFromFileTTF(terminus_fn, 14, nil, ranges[0].addr)
  #assert small_font != nil
  #assert small_font.isLoaded()
  large_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len, 36, nil, ascii_ranges[0].addr)
  #large_font = atlas.addFontFromFileTTF(terminus_fn, 36)
  #assert large_font != nil
  #assert large_font.isLoaded()
  atlas.build()

  atlas.add_custom_glyph rect_id

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

type
  Loggable[T] = ref object
    name: cstring
    values: seq[T]
    size: int32
    phase: int32
    low, high: T

proc current*[T](l: Loggable[T]): T =
  return l.values[l.phase]

proc log*[T](l: var Loggable[T], value: T) {.inline.} =
  l.phase.inc
  if l.phase >= l.values.len:
    l.phase = 0

  l.values[l.phase] = value

#[# for posterity:
proc get_loggable_value*[T](data: pointer, index: int32): T {.cdecl, varargs.} =
  return cast[ptr Loggable[T]](data).values[index]
#]#

proc plot*[T](l: var Loggable[T]) =
  let clk =
    l.values.min().formatFloat(ffDecimal, 3) & " ≤ " &
    l.current().formatFloat(ffDecimal, 3) & " ≤ " &
    l.values.max().formatFloat(ffDecimal, 3)
  var cclk = clk.cstring

  const graph_size = ImVec2(x: 128, y: 50)
  igPlotLines(l.name, l.values[0].addr, l.size, l.phase, cclk, l.low, l.high, graph_size) #, stride: int32 = sizeof(float32).int32): void {.importc: "igPlotLines_FloatPtr".}
  #igPlotEx ImGuiPlotType.Lines, l.name, get_loggable_value[T], l.addr, l.size, l.phase, cclk, l.low, l.high

proc newLoggable*[T](name: cstring, low, high: T): Loggable[T] =
  const size = 256
  result = Loggable[T](
    size: size,
    low: low,
    high: high,
    values: newSeq[T](size),
    name: name,
  )


type
  Logs = ref object
    frame_time*   : Loggable[float32]
    player_vel_y* : Loggable[float32]
    player_acc_y* : Loggable[float32]
    air*          : Loggable[float32]

var logs* = Logs(
  frame_time   : newLoggable[float32]("frame time"  ,  4f,  64f),
  player_vel_y : newLoggable[float32]("player vel.y", -64f, 64f),
  player_acc_y : newLoggable[float32]("player acc.y", -100f, 100f),
  air          : newLoggable[float32]("air"         ,  -1f, 10f),
)

iterator items*(logs: Logs): var Loggable[float32] =
  yield logs.frame_time
  yield logs.player_vel_y
  yield logs.player_acc_y
  yield logs.air

proc log_frame_time*(frame_time: float32) =
  logs.frame_time.log frame_time

proc draw_stats*[T](value: T) =
  #igSetNextWindowPos(ImVec2(x: (width - 112).float32, y: 0))
  #igSetNextWindowSize(ImVec2(x:112, y:48))

  if igBegin("stats"):#, nil, ImGuiWindowFlags(171)):
    for loggable in logs:
      loggable.plot()
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
    dirty = igDragFloat( "ambient"   , light.ambient.data.addr , 1/256f, 0f, 1f      ) or dirty
    dirty = igColorEdit3("specular"  , light.specular.data.arr                      ) or dirty
  igEnd()
  result = dirty

iterator pieces_by_kind[T: Piece](s: seq[T]): (CliffMask, var seq[T]) =
  # TODO this is inefficient
  var tbl = newTable[CliffMask, seq[T]]()
  for f in s:
    if not tbl.hasKey f.kind:
      tbl[f.kind] = @[]
    tbl[f.kind].add f
  for k,v in tbl.mpairs:
    yield (k,v)

proc info_window*(actors: ActorSet) =
  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("actors")

  for kind, s in actors.pieces_by_kind:
    var k = cstring $kind
    if igCollapsingHeader(k, DefaultOpen):
      for a, actor in s.mpairs:
        var name: cstring

        name = cstring("pos##" & $a)
        igDragFloat3 name, actor.mesh.pos.arr, 0.125, -sky, sky

        name = cstring("vel##" & $a)
        igDragFloat3 name, actor.mesh.vel.arr, 0.125, -96f, 96f

        name = cstring("acc##" & $a)
        igDragFloat3 name, actor.mesh.acc.arr, 0.125, -96f, 96f

        name = cstring("scale##" & $a)
        igDragFloat3 name, actor.mesh.scale.arr, 0.125, 0f, 2f

        name = cstring("facing##" & $a)
        var dir = arctan2( actor.facing.z , actor.facing.x ).degrees
        if dir < 0: dir += 360f
        igDragFloat name, dir.addr

        igSeparator()
  igEnd()

import models
proc info_window*(fixtures: seq[Fixture]) =
  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("fixtures")
  for kind, s in fixtures.pieces_by_kind:
    var k = cstring $kind
    if igCollapsingHeader(k, DefaultOpen):
      for f, fixture in s.mpairs:

        let name = cstring "pos##" & $f
        igDragFloat3 name   , fixture.mesh.pos.arr, 0.125, -sky, sky

        let tname = cstring "translate##" & $f
        igDragFloat3 tname   , fixture.mesh.translate.arr, 0.125, -12f, 12f

        let rotname = cstring "rot##" & $f
        igDragFloat4 rotname, fixture.mesh.rot.arr, 1f.radians, -180f.radians, 180f.radians

        let offname = cstring "offset##" & $f
        igDragInt  offname, fixture.mesh.elem_vbo.offset.addr, wave_ninds, 0, wave_ninds * wave_res * wave_len

        if kind == SW:
          let hname = cstring "height##" & $f
          var height: float32 = fixture.wave_height(0.0)
          igDragFloat hname, height.addr, 0.125, -sky, sky

        igSeparator()
      igSpacing()
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
  # TODO refactor this to use Gamepad API
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
      if igMenuItem("0"): app.selected_level = 1
      if igMenuItem("1"): app.selected_level = 2
      if igMenuItem("2"): app.selected_level = 3
      if igMenuItem("3"): app.selected_level = 4
      if igMenuItem("4"): app.selected_level = 5
      if igMenuItem("5"): app.selected_level = 6
      if igMenuItem("6"): app.selected_level = 7
      igEndMenu()
    if igBeginMenu("Windows"):
      igMenuItem "Player"      , nil, addr app.show_player
      igMenuItem "Light"       , nil, addr app.show_light
      igMenuItem "Camera"      , nil, addr app.show_camera
      igMenuItem "Actors"      , nil, addr app.show_actors
      igMenuItem "Fixtures"    , nil, addr app.show_fixtures
      igMenuItem "Level"       , nil, addr app.show_level
      igMenuItem "Editor"      , "E", addr app.show_editor
      igMenuItem "Keymap"      , "?", addr app.show_keymap
      igMenuItem "Joystick"    , "J", addr app.show_joystick
      igMenuItem "Metrics"     , nil, addr app.show_metrics
      igMenuItem "Masks"       , nil, addr app.show_masks
      igEndMenu()
    discard
  igEndMainMenuBar()


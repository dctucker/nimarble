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

include input

proc setup_glfw(): GLFWWindow =
  doAssert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_FALSE)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFW_FALSE);

  #(width, height) = display_size()
  let w = glfwCreateWindow(width, height, "Nimarble", nil, nil)
  doAssert w != nil

  w.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorDisabled
  #w.setCursor GLFWCursorDisabled
  if glfwRawMouseMotionSupported() == GLFW_TRUE:
    w.setInputMode GLFW_RAW_MOUSE_MOTION, GLFW_TRUE
  discard w.setKeyCallback(keyProc)
  discard w.setCursorPosCallback(mouseProc)
  discard w.setScrollCallback(scrollProc)
  w.makeContextCurrent()
  let mid = middle()
  w.setCursorPos mid.x, mid.y
  #w.setWindowOpacity(0.9)
  result = w

  when defined(windows):
    var hwnd = w.getWin32Window()
    doAssert hwnd != nil

proc setup_opengl() =
  doAssert glInit()

  glClearColor 0f, 0f, 0.1f, 1f
  glClear      GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
  glEnable     GL_DEPTH_TEST
  glDepthFunc  GL_LESS       # Accept fragment if it closer to the camera than the former one

  glEnable     GL_BLEND
  glBlendFunc  GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA
  #glShadeModel GL_FLAT

  glEnable     GL_LINE_SMOOTH
  glLineWidth  2f

  #glEnable    GL_CULL_FACE
  #glCullFace  GL_BACK
  #glFrontFace GL_CW

include windows/player

proc compute_model(mesh: var Mesh) =
  mesh.model.mat = mat4(1.0f)
    .translate(mesh.pos * vec3f(1,level_squash,1))
    .translate(mesh.translate)
    .scale(mesh.scale) * mesh.rot.mat4f

proc render*(game: var Game, mesh: var Mesh) =
  mesh.mvp.mat = game.proj * game.view.mat.translate(-game.camera.pan.pos) * mesh.model.mat
  mesh.render()

proc render[T: Piece](piece: var T) =
  var mesh = piece.mesh
  mesh.compute_model()

  game.render(mesh)

proc render[T: Selector](selector: var T) =
  selector.mesh.compute_model()
  game.render selector.mesh

proc render[T: Cursor](cursor: var T) =
  cursor.mesh.compute_model()
  cursor.mesh.wireframe = true
  game.render cursor.mesh
  cursor.mesh.wireframe = false
  game.render cursor.mesh
  if editor.focused:
    cursor.phase.inc

  var scale = 1.125 + 0.25 * ((cursor.phase mod 40) - 20).abs.float / 20f
  cursor.mesh.scale.xz = vec2f(scale)

proc sync_editor =
  var player = game.player
  var mesh = player.mesh
  let coord = player.coord
  if not editor.focused:
    editor.col = editor.level.origin.x + coord.x.floor.int
    editor.row = editor.level.origin.z + coord.z.floor.int
  else:
    mesh.pos.x = editor.col.float - editor.level.origin.x.float
    mesh.pos.z = editor.row.float - editor.level.origin.z.float
    let point = editor.level.map[editor.row, editor.col]
    editor.cursor.mesh.pos = vec3f( mesh.pos.x, point.height, mesh.pos.z )
    editor.cursor.cube = point.cube
  if app.show_editor:
    editor.draw()

proc `or`*(f1, f2: ImGuiWindowFlags): ImGuiWindowFlags =
  return ImGuiWindowFlags( f1.ord or f2.ord )

proc draw_imgui =
  glEnable           GL_POLYGON_OFFSET_FILL
  glPolygonOffset 1f, 1f
  glPolygonMode GL_FRONT_AND_BACK, GL_FILL

  igPushFont( small_font )

  app.main_menu()
  if app.show_player:
    info_player()

  var level = game.level
  if app.show_actors: level.actors.info_window()
  if app.show_fixtures: level.fixtures.info_window()

  if app.show_level:
    level.info_window(game.player.coord)

  if app.show_camera:
    if game.camera.info_window():
      game.view.mat = lookAt( game.camera.pos, game.camera.target, game.camera.up )
      game.update_camera()

  if app.show_light:
    if game.light.info_window():
      game.light.update()

  if app.show_masks:
    XX.info_window()
  if app.show_metrics:
    igShowMetricsWindow()

  igBegin("selector")
  igDragFloat3("pos", editor.selector.mesh.pos.arr, 1, -sky, sky)
  igDragFloat3("scale", editor.selector.mesh.scale.arr, 1, -sky, sky)
  igEnd()

  sync_editor()
  igPopFont()

proc imgui_frame =
  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  draw_imgui()

  if game.goal:
    draw_goal()

  #draw_stats(t)
  frame_time.draw_stats()

  if app.show_keymap:
    if editor.focused:
      draw_keymap editor_keymap, editor_keymap_shift, editor_keymap_command
    else:
      draw_keymap game_keymap  , game_keymap_shift  , game_keymap_command

  if app.show_joystick:
    joystick.info_window()

  igRender()
  igOpenGL3RenderDrawData(igGetDrawData())

  if app.selected_level != 0:
    game.level_number = app.selected_level.int32
    game.set_level()
    app.selected_level = 0

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()

proc god: bool = return game.god or editor.focused

proc physics[T](game: var Game, pieces: var T, dt: float) =
  for actor in pieces.mitems:
    game.physics(actor, dt)

include physics

proc visible*(p: Player): bool =
  result = p.animation != Teleport
  result = result and not editor.focused

proc main =
  editor = Editor(cursor_data: true, cursor_mask: true, stamp: Stamp(width:0, height: 0))
  game = newGame()
  let w = setup_glfw()

  setup_opengl()
  setup_imgui(w)

  game.init()
  game.light.update()


  # main loop
  while not w.windowShouldClose():
    var level = game.level
    var player = game.player
    var floor_plane = level.floor_plane
    var actors = level.actors
    var fixtures = level.fixtures
    time = glfwGetTime()
    dt = time - t
    t = time

    if game.paused and game.frame_step:
      game.physics()
      game.frame_step = false
    elif not game.paused:
      game.physics()

    if not game.paused:
      if game.following:
        game.follow_player()

    if editor.focused:
      game.camera.pan.maxvel = 10f
      game.camera.maxvel = 1f
    else:
      game.camera.pan.maxvel = 0.25f
      game.camera.maxvel = 1f/5f
    game.camera.physics(dt)

    glClear            GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    floor_plane.wireframe = game.wireframe
    game.render floor_plane
    floor_plane.wireframe = true
    game.render floor_plane

    player.mesh.compute_model()
    if player.visible:
      player.mesh.wireframe = game.wireframe
      game.render player.mesh

    for actor in actors.mitems:
      actor.mesh.wireframe = game.wireframe
      actor.render()

    for fixture in fixtures.mitems:
      fixture.mesh.wireframe = game.wireframe
      fixture.render()

    editor.cursor.render()
    editor.selector.render()

    imgui_frame()

    w.swapBuffers()
    fps_count()

    game.poll_joystick()
    glfwPollEvents()

  w.cleanup()

#start_level = 5.int32
main()

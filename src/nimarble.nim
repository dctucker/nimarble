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
]

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

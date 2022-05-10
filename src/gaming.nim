from nimgl/glfw import setInputMode, setCursorPos, GLFW_CURSOR_SPECIAL, GLFW_CURSOR_NORMAL, GLFWCursorDisabled, setWindowShouldClose
import glm

import types
import wrapper
import window
import models
import scene
import shaders
from leveldata import get_level, sky, load_level
from editing import focus, leave

const level_squash* = 0.5f
const start_level* = 1

var editor*: Editor

proc rotate_coord*(v: Vec3f): Vec3f =
  let v4 = mat4f(1f).translate(v).rotateY(radians(45f))[3]
  result = vec3f(v4.x, v4.y, v4.z)

proc update_camera*(game: Game) =
  let level = game.get_level()

  let distance = game.camera_distance
  game.camera_target = vec3f( 0, level.origin.y.float * level_squash, 0 )
  game.camera_pos = vec3f( distance, game.camera_target.y + distance, distance )
  game.camera_up = vec3f( 0f,  1.0f,  0f )
  #let target = vec3f( 10, 0, 10 )
  #let pos = vec3f( level.origin.z.float * 2, 0, level.origin.z.float * 2)
  game.view.update lookAt( game.camera_pos, game.camera_target, game.camera_up )
  game.light.update()

const field_width = 10f
proc update_fov*(game: Game) =
  let r: float32 = radians(game.fov)
  game.proj = perspective(r, aspect, 0.125f, sky)
  #game.proj = ortho(aspect * -field_width, aspect * field_width, -field_width, field_width, 0f, sky) # In world coordinates

proc reset_view*(game: Game) =
  game.update_fov()
  game.update_camera()
  game.pan_vel = vec3f(0,0,0)

proc reset_player*(game: Game) =
  let player_top = game.get_level().origin.y.float
  game.player.mesh.reset()
  game.player.mesh.pos += vec3f(0.5, 0.5, 0.5)
  game.player.mesh.pos.y = player_top

proc do_reset_player*(game: Game, press: bool) =
  if press:
    game.reset_player()

proc respawn*(game: Game, press: bool) =
  if press:
    game.reset_player()
    game.player.mesh.pos = game.respawn_pos
    game.reset_view()
    inc game.respawns

proc follow_player*(game: Game) =
  let level = game.get_level()
  let coord = game.player.mesh.pos.rotate_coord
  let target = game.player.mesh.pos# * 0.5f

  let y = (game.player.mesh.pos.y - level.origin.y.float) * 0.5
  game.pan_target = vec3f( coord.x, y, coord.z )

  let ly = target.y
  if game.goal:
    return

proc update_mouse_mode*(game: Game) =
  case game.mouse_mode
  of MouseOff:
    game.window.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorNormal
  of MouseAcc:
    let mid = middle()
    game.window.setCursorPos mid.x, mid.y
    mouse *= 0
    game.window.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorDisabled
  else:
    discard

proc toggle_pause*(game: Game) =
  game.paused = not game.paused
  if game.paused:
    game.mouse_mode = MouseOff
    game.update_mouse_mode()

proc toggle_mouse_lock*(game: Game, press: bool) =
  if not press:
    return
  if game.mouse_mode == MouseOff:
    game.mouse_mode = MouseAcc
  else:
    game.mouse_mode = MouseOff
  game.update_mouse_mode()

proc init_player*(game: var Game) =
  game.player.mesh = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, sphere),
    color_vbo: newVBO(4, sphere_colors),
    norm_vbo: newVBO(3, sphere_normals),
    elem_vbo: newElemVBO(sphere_index),
    program: newProgram(player_frags, player_verts, player_geoms),
  )
  game.reset_player()

  var modelmat = mat4(1.0f)
  game.player.mesh.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.pan) * game.player.mesh.model.mat
  game.player.mesh.mvp = game.player.mesh.program.newMatrix(mvp, "MVP")


proc init_floor_plane*(game: Game) =
  let level = game.get_level()
  if level.floor_plane != nil:
    return
  load_level game.level
  level.floor_plane = Mesh(
    vao: newVAO(),
    vert_vbo  : newVBO(3, level.floor_verts),
    color_vbo : newVBO(4, level.floor_colors),
    norm_vbo  : newVBO(3, level.floor_normals),
    elem_vbo  : newElemVBO(level.floor_index),
    program   : game.player.mesh.program,
  )
  var modelmat = mat4(1.0f).scale(1f, level_squash, 1f)
  level.floor_plane.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.pan) * level.floor_plane.model.mat
  level.floor_plane.mvp = level.floor_plane.program.newMatrix(mvp, "MVP")

proc init_actors*(game: Game) =
  let level = game.get_level()
  for actor in level.actors.mitems:
    if actor.mesh != nil:
      continue
    var modelmat = mat4(1.0f)
    actor.mesh = Mesh(
      vao       : newVAO(),
      vert_vbo  : newVBO(3, sphere),
      color_vbo : newVBO(4, sphere_enemy_colors),
      elem_vbo  : newElemVBO(sphere_index),
      program   : game.player.mesh.program,
      model     : game.player.mesh.program.newMatrix(modelmat, "M"),
    )
    actor.mesh.reset()
    let x = (actor.origin.x - level.origin.x).float
    let y = actor.origin.y.float
    let z = (actor.origin.z - level.origin.z).float

    actor.mesh.pos    = vec3f(x, y, z)
    var mvp = game.proj * game.view.mat.translate(-game.pan) * actor.mesh.model.mat
    actor.mesh.mvp = game.player.mesh.program.newMatrix(mvp, "MVP")

proc set_level*(game: Game) =
  let f = game.following
  game.following = false
  game.goal = false
  game.hourglass = 0
  game.reset_player()
  game.init_floor_plane()
  game.init_actors()
  game.reset_player()
  game.follow_player()
  game.pan = game.pan_target
  game.reset_view()
  game.following = f
  editor.level = game.get_level()
  editor.name = editor.level.name

proc init*(game: var Game) =
  game.init_player()
  var viewmat = game.view.mat
  game.view = game.player.mesh.program.newMatrix(viewmat, "V")

  game.light.get_uniform_locations(game.player.mesh.program)

  game.level = start_level
  game.set_level()
  game.init_floor_plane()
  game.init_actors()
  game.light.update()


proc pan_stop(game: Game) =
  game.pan_acc = vec3f(0f,0f,0f)

proc pan_up*(game: Game, press: bool) =
  if press: game.pan_acc.xz = vec2f(-0.125f, -0.125)
  else: game.pan_stop()
proc pan_down*(game: Game, press: bool) =
  if press: game.pan_acc.xz = vec2f(+0.125, +0.125)
  else: game.pan_stop()
proc pan_left*(game: Game, press: bool) =
  if press: game.pan_acc.xz = vec2f(-0.125, +0.125)
  else: game.pan_stop()
proc pan_right*(game: Game, press: bool) =
  if press: game.pan_acc.xz = vec2f(+0.125, -0.125)
  else: game.pan_stop()
proc pan_in*(game: Game, press: bool) =
  if press: game.pan_acc.y = +0.125
  else: game.pan_stop()
proc pan_out*(game: Game, press: bool) =
  if press: game.pan_acc.y = -0.125
  else: game.pan_stop()

proc pan_cw*(game: Game, press: bool) =
  if press:
    let y = game.camera_pos.y
    let pos = game.camera_pos.xz
    let distance = game.camera_pos.xz.length
    let xz = distance * normalize(pos + vec2f(1,-1))
    game.camera_pos = vec3f(xz.x, y, xz.y)
    game.view.update lookAt( game.camera_pos, game.camera_target, game.camera_up )

proc pan_ccw*(game: Game, press: bool) =
  if press:
    let y = game.camera_pos.y
    let pos = game.camera_pos.xz
    let distance = game.camera_pos.xz.length
    let xz = distance * normalize(pos + vec2f(-1,1))
    game.camera_pos = vec3f(xz.x, y, xz.y)
    game.view.update lookAt( game.camera_pos, game.camera_target, game.camera_up )

proc step_frame*(game: Game, press: bool) =
  if press: game.frame_step = true
proc prev_level*(game: Game, press: bool) =
  if press:
    dec game.level
    game.set_level()
proc next_level*(game: Game, press: bool) =
  if press:
    inc game.level
    game.set_level()
proc follow*(game: Game, press: bool) =
  if press:
    game.following = not game.following
  if not game.following:
    game.pan_target = game.pan
    game.pan_vel *= 0
proc do_goal*(game: Game, press: bool) =
  if press: game.goal = not game.goal
proc toggle_wireframe*(game: Game, press: bool) =
  if press: game.wireframe = not game.wireframe
proc pause*(game: Game, press: bool) =
  if press: game.toggle_pause()
proc do_quit*(game: Game, press: bool) =
  game.window.setWindowShouldClose(true)

proc toggle_god*(game: Game, press: bool) =
  if press: game.god = not game.god

proc focus_editor*(game: Game, press: bool) =
  if not press: return
  editor.visible = true

  editor.focused = not editor.focused

  if editor.focused:
    editor.focus()
  else:
    editor.leave()

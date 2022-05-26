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

var app* = Application() # ugh, this needs to be moved out
var editor*: Editor

action:
  proc animate_step*(game: var Game, press: bool) =
    if press: game.animate_next_step = true

proc rotate_coord*(v: Vec3f): Vec3f =
  let v4 = mat4f(1f).translate(v).rotateY(radians(45f))[3]
  result = vec3f(v4.x, v4.y, v4.z)

proc update_camera*(game: Game) =
  let distance = game.camera.distance
  game.camera.target = vec3f( 0, game.level.origin.y.float * level_squash, 0 )
  game.camera.pos = vec3f( distance, game.camera.target.y + distance, distance )
  game.camera.up = vec3f( 0f,  1.0f,  0f )
  #let target = vec3f( 10, 0, 10 )
  #let pos = vec3f( game.level.origin.z.float * 2, 0, game.level.origin.z.float * 2)
  game.view.update lookAt( game.camera.pos, game.camera.target, game.camera.up )
  game.light.update()

const field_width = 10f
proc update_fov*(game: Game) =
  let r: float32 = radians(game.camera.fov)
  game.proj = perspective(r, aspect, 0.125f, sky)
  #game.proj = ortho(aspect * -field_width, aspect * field_width, -field_width, field_width, 0f, sky) # In world coordinates

proc reset_view*(game: var Game) =
  game.update_fov()
  game.update_camera()
  game.pan.vel = vec3f(0,0,0)

proc reset_player*(game: var Game) =
  let player_top = game.level.origin.y.float
  game.player.mesh.reset()
  game.player.mesh.scale = vec3f(1,1,1)
  game.player.mesh.pos += vec3f(0.5, 0.5, 0.5)
  game.player.mesh.pos.y = player_top

proc follow_player*(game: var Game) =
  let coord = game.player.mesh.pos.rotate_coord
  let target = game.player.mesh.pos# * 0.5f

  let y = (game.player.mesh.pos.y - game.level.origin.y.float) * 0.5
  game.pan.target = vec3f( coord.x, y, coord.z )

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

proc toggle_pause*(game: var Game) =
  game.paused = not game.paused
  if game.paused:
    game.mouse_mode = MouseOff
    game.update_mouse_mode()

proc init_player*(game: var Game) =
  if game.player.mesh == nil:
    game.player.mesh = Mesh(
      primitive : GL_TRIANGLE_STRIP,
      vao: newVAO(),
      vert_vbo: newVBO(3, sphere),
      color_vbo: newVBO(4, sphere_colors),
      norm_vbo: newVBO(3, sphere_normals),
      elem_vbo: newElemVBO(sphere_index),
      program: newProgram(player_frags, player_verts, player_geoms),
    )
  if game.level != nil:
    game.reset_player()

  var modelmat = mat4(1.0f)
  game.player.mesh.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.pan.pos) * game.player.mesh.model.mat
  game.player.mesh.mvp = game.player.mesh.program.newMatrix(mvp, "MVP")


proc init_floor_plane*(game: var Game) =
  if game.level.floor_plane != nil:
    return
  load_level game.level_number
  game.level.floor_plane = Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao: newVAO(),
    vert_vbo  : newVBO(3, game.level.floor_verts),
    color_vbo : newVBO(4, game.level.floor_colors),
    norm_vbo  : newVBO(3, game.level.floor_normals),
    elem_vbo  : newElemVBO(game.level.floor_index),
    program   : game.player.mesh.program,
  )
  var modelmat = mat4(1.0f).scale(1f, level_squash, 1f)
  game.level.floor_plane.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.pan.pos) * game.level.floor_plane.model.mat
  game.level.floor_plane.mvp = game.level.floor_plane.program.newMatrix(mvp, "MVP")

proc newMesh(game: var Game, verts, colors, norms: var seq[cfloat], elems: var seq[Ind]): Mesh =
  var modelmat = mat4f(1)
  result = Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao       : newVAO(),
    vert_vbo  : newVBO(3, verts),
    color_vbo : newVBO(4, colors),
    norm_vbo  : newVBO(3, norms),
    elem_vbo  : newElemVBO(elems),
    program   : game.player.mesh.program,
    model     : game.player.mesh.program.newMatrix(modelmat, "M"),
    scale     : vec3f(1,1,1)
  )
  result.reset()

var shared_wave_verts: VBO[cfloat]
var shared_wave_colors: VBO[cfloat]
var shared_wave_norms: VBO[cfloat]

proc newMesh(game: var Game, piece: Piece): Mesh =
  case piece.kind
  of EM:
    result = newMesh( game, sphere      , enemy_colors       , sphere_normals      , sphere_index )
  of EY: result = newMesh( game, yum         , yum_colors         , sphere_normals      , sphere_index )
  of EA: result = newMesh( game, acid_verts  , acid_colors        , acid_normals        , acid_index   )
  of EP:
    result = newMesh( game, piston_verts, piston_colors      , piston_normals      , piston_index )
    result.rot = quatf(vec3f(1, 0, 0).normalize, 90f.radians)
    result.scale = vec3f(1f, 2f, 1f)
    result.pos = vec3f(0.5, -1.96875, 0.5)
  of GR:
    var verts   = single_rail
    var colors  = single_rail_colors
    var normals = single_rail_normals
    var index   = single_rail_index
    var modelmat = mat4f(1)
    result = Mesh(
      primitive : GL_TRIANGLE_STRIP,
      vao       : newVAO(),
      vert_vbo  : newVBO(3, verts),
      color_vbo : newVBO(4, colors),
      norm_vbo  : newVBO(3, normals),
      elem_vbo  : newElemVBO(index),
      program   : game.player.mesh.program,
      model     : game.player.mesh.program.newMatrix(modelmat, "M"),
      rot       : quatf(vec3f(1, 0, 0).normalize, 90f.radians),
      scale     : vec3f(1,1,1),
    )
    result.pos = vec3f(0.5, 0.0, 0.5)

  of SW:
    # wavelength is 12 units of 16 pixels each
    if shared_wave_verts.n_verts == 0:
      echo "init shared wave vbos"
      shared_wave_verts  = newVBO(3, wave_verts)
      shared_wave_colors = newVBO(4, wave_colors)
      shared_wave_norms  = newVBO(3, wave_normals)
    var modelmat = mat4f(1)
    result = Mesh(
      primitive : GL_TRIANGLE_STRIP,
      vao       : newVAO(),
      vert_vbo  : shared_wave_verts,
      color_vbo : shared_wave_colors,
      norm_vbo  : shared_wave_norms,
      elem_vbo  : newElemVBO(wave_index),
      program   : game.player.mesh.program,
      model     : game.player.mesh.program.newMatrix(modelmat, "M"),
      scale     : vec3f(1f/wave_res,3,1),
    )
    let xm = (piece.origin.x mod wave_len).float
    let offset = cint xm * wave_ninds * wave_res
    result.elem_vbo.offset = offset
    result.elem_vbo.n_verts = wave_res * wave_ninds - 1
    result.translate.x = -xm
    result.translate.y = -1/32f
    #result.translate.z = (piece.origin.x mod 2).float * 0.125 # ugly debug

  else:
    result = newMesh( game, sphere      , sphere_normals     , sphere_normals      , sphere_index )

proc init_piece*[T](game: var Game, piece: var T) =
  piece.mesh = game.newMesh(piece)
  let x = (piece.origin.x - game.level.origin.x).float
  let y =  piece.origin.y.float
  let z = (piece.origin.z - game.level.origin.z).float

  if MI in game.level.map[ piece.origin.z, piece.origin.x ].masks:
    piece.mesh.scale *= 0.5
  piece.mesh.pos    += vec3f(x, y, z)
  var mvp = game.proj * game.view.mat.translate(-game.pan.pos) * piece.mesh.model.mat
  piece.mesh.mvp = game.player.mesh.program.newMatrix(mvp, "MVP")

proc init_fixtures*(game: var Game) =
  for fixture in game.level.fixtures.mitems:
    if fixture.mesh != nil:
      continue
    game.init_piece(fixture)

proc init_actors*(game: var Game) =
  for actor in game.level.actors.mitems:
    if actor.mesh != nil:
      continue
    game.init_piece(actor)
    if actor.kind == EM:
      actor.facing = vec3f(0,0,-1)

proc set_level*(game: var Game) =
  var num = game.level_number
  game.level = get_level(num)
  game.level_number = num
  let f = game.following
  game.following = false
  game.goal = false
  game.hourglass = 0
  game.reset_player()
  game.init_floor_plane()
  game.init_actors()
  game.init_fixtures()

  game.reset_player()
  game.player.respawn_pos = game.player.mesh.pos
  game.follow_player()
  game.pan.pos = game.pan.target
  game.reset_view()
  game.following = f

  editor.level = game.level
  editor.name = editor.level.name

proc init*(game: var Game) =
  game.init_player()
  var viewmat = game.view.mat
  game.view = game.player.mesh.program.newMatrix(viewmat, "V")

  game.light.get_uniform_locations(game.player.mesh.program)

  game.level_number = start_level
  game.set_level()
  game.init_floor_plane()
  game.init_actors()
  game.init_fixtures()
  game.light.update()

proc respawn*(game: var Game) =
    game.player.dead = false
    game.player.mesh.elem_vbo.offset = 0
    game.reset_player()
    game.reset_view()
    inc game.respawns

proc pan_stop(game: var Game) =
  game.pan.acc = vec3f(0f,0f,0f)

action:
  proc choose_level*(game: var Game, press: bool) =
    let choice = game.recent_input.ord - '0'.ord
    game.level_number = choice.int32
    game.set_level()

  proc toggle_all*(game: var Game, press: bool) =
    if not press: return
    if app.toggle():
      game.mouse_mode = MouseOff
    else:
      game.mouse_mode = MouseAcc
    game.update_mouse_mode()

  proc toggle_keymap*(game: var Game, press: bool) =
    if press: app.show_keymap = not app.show_keymap

  proc do_reset_player*(game: var Game, press: bool) =
    if press:
      game.reset_player()

  proc do_respawn*(game: var Game, press: bool) =
    if press:
      game.respawn()

  proc toggle_mouse_lock*(game: var Game, press: bool) =
    if not press:
      return
    if game.mouse_mode == MouseOff:
      game.mouse_mode = MouseAcc
    else:
      game.mouse_mode = MouseOff
    game.update_mouse_mode()

  proc pan_up*(game: var Game, press: bool) =
    if press: game.pan.acc.xz = vec2f(-0.125f, -0.125)
    else: game.pan_stop()
  proc pan_down*(game: var Game, press: bool) =
    if press: game.pan.acc.xz = vec2f(+0.125, +0.125)
    else: game.pan_stop()
  proc pan_left*(game: var Game, press: bool) =
    if press: game.pan.acc.xz = vec2f(-0.125, +0.125)
    else: game.pan_stop()
  proc pan_right*(game: var Game, press: bool) =
    if press: game.pan.acc.xz = vec2f(+0.125, -0.125)
    else: game.pan_stop()
  proc pan_in*(game: var Game, press: bool) =
    if press: game.pan.acc.y = +0.125
    else: game.pan_stop()
  proc pan_out*(game: var Game, press: bool) =
    if press: game.pan.acc.y = -0.125
    else: game.pan_stop()

  proc pan_cw*(game: var Game, press: bool) =
    if press:
      let y = game.camera.pos.y
      let pos = game.camera.pos.xz
      let distance = game.camera.pos.xz.length
      let xz = distance * normalize(pos + vec2f(1,-1))
      game.camera.pos = vec3f(xz.x, y, xz.y)
      game.view.update lookAt( game.camera.pos, game.camera.target, game.camera.up )

  proc pan_ccw*(game: var Game, press: bool) =
    if press:
      let y = game.camera.pos.y
      let pos = game.camera.pos.xz
      let distance = game.camera.pos.xz.length
      let xz = distance * normalize(pos + vec2f(-1,1))
      game.camera.pos = vec3f(xz.x, y, xz.y)
      game.view.update lookAt( game.camera.pos, game.camera.target, game.camera.up )

  proc step_frame*(game: var Game, press: bool) =
    if press: game.frame_step = true

  proc prev_level*(game: var Game, press: bool) =
    if press:
      dec game.level_number
      game.set_level()

  proc next_level*(game: var Game, press: bool) =
    if press:
      inc game.level_number
      game.set_level()
  proc follow*(game: var Game, press: bool) =
    if press:
      game.following = not game.following
    if not game.following:
      game.pan.target = game.pan.pos
      game.pan.vel *= 0
  proc do_goal*(game: var Game, press: bool) =
    if press: game.goal = not game.goal
  proc toggle_wireframe*(game: var Game, press: bool) =
    if press: game.wireframe = not game.wireframe
  proc pause*(game: var Game, press: bool) =
    if press: game.toggle_pause()
  proc do_quit*(game: var Game, press: bool) =
    game.window.setWindowShouldClose(true)

  proc toggle_god*(game: var Game, press: bool) =
    if press: game.god = not game.god

  proc focus_editor*(game: var Game, press: bool) =
    if not press: return
    if editor.visible == false:
      toggle_mouse_lock.callback(game, true)
    editor.visible = true
    app.show_editor = true

    editor.focused = not editor.focused

    if editor.focused:
      editor.focus()
    else:
      editor.leave()

proc hazard(actor: Actor): bool =
  return actor.kind.hazard

proc safe*(game: Game): bool =
  const distance = 5f
  let player_pos = game.player.mesh.pos
  for actor in game.level.actors:
    if not actor.hazard: continue
    if (actor.mesh.pos - player_pos).length < distance:
      return false
  return true

proc die*(player: var Player, why: string) =
  echo why
  player.dead = true

proc animate*(player: var Player, ani: Animation, t: float) =
  player.animation_time = t
  player.animation = ani

proc animate*(player: var Player, t: float): bool =
  if player.animation == Animation.None:
    return false
  if player.animation_time <= 0:
    return false
  if t >= player.animation_time:
    player.animation_time = 0f
    player.animation = player.animation.next

  case player.animation
  of Dissolve:
    player.die("dissolving")
    player.mesh.pos.y -= 0.03125f
  of Respawn:
    player.mesh.vel *= 0
    player.mesh.acc *= 0
    player.mesh.scale = vec3f(1,1,1)
    player.mesh.pos = player.respawn_pos
  of Break:
    if player.mesh.scale.y < 0.5f:
      player.mesh.scale *= 255/256f
    else:
      player.mesh.scale *= vec3f(513/512f, 127/128f, 513/512f)
      player.mesh.scale = clamp( player.mesh.scale, 0.1, 1.5 )
  of Stun:
    const peak = 1.375
    let left = player.animation_time - t
    var spin: float32
    if left > peak:
      spin = 1f - ((left - peak) / (1.5 - peak))
    else:
      spin = left / peak
    #echo spin
    player.mesh.rot = player.mesh.rot.rotate(20f.radians * spin, vec3f(0,1,0))
    return false
  else:
    discard

  return true



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
  game.camera.pan.pos = game.camera.pan.target
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

  game.init_cursor()
  game.init_selector()

proc respawn*(game: var Game) =
    game.player.dead = false
    game.player.mesh.elem_vbo.offset = 0
    game.reset_player()
    game.reset_view()
    inc game.respawns

action:
  proc animate_step*(game: var Game, press: bool) =
    if press: game.animate_next_step = true

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
    if press: game.camera.pan.acc.xz = vec2f(-0.125f, -0.125)
    else: game.pan_stop()
  proc pan_down*(game: var Game, press: bool) =
    if press: game.camera.pan.acc.xz = vec2f(+0.125, +0.125)
    else: game.pan_stop()
  proc pan_left*(game: var Game, press: bool) =
    if press: game.camera.pan.acc.xz = vec2f(-0.125, +0.125)
    else: game.pan_stop()
  proc pan_right*(game: var Game, press: bool) =
    if press: game.camera.pan.acc.xz = vec2f(+0.125, -0.125)
    else: game.pan_stop()
  proc pan_in*(game: var Game, press: bool) =
    if press: game.camera.pan.acc.y = +0.125
    else: game.pan_stop()
  proc pan_out*(game: var Game, press: bool) =
    if press: game.camera.pan.acc.y = -0.125
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
      game.camera.pan.target = game.camera.pan.pos
      game.camera.pan.vel *= 0
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
      game.mouse_mode = MouseOff
    editor.visible = true
    app.show_editor = true

    editor.focused = not editor.focused

    if editor.focused:
      editor.focus()
    else:
      editor.leave()



proc update_camera*(game: Game) =
  let distance = game.camera.distance
  game.camera.target = vec3f( 0, game.level.origin.y.float * level_squash, 0 )
  game.camera.pos = vec3f( distance, game.camera.target.y + distance, distance )
  game.camera.up = vec3f( 0f,  1.0f,  0f )
  #let target = vec3f( 10, 0, 10 )
  #let pos = vec3f( game.level.origin.z.float * 2, 0, game.level.origin.z.float * 2)
  game.view.update lookAt( game.camera.pos, game.camera.target, game.camera.up )
  game.light.update()

proc update_fov*(game: Game) =
  let r: float32 = radians(game.camera.fov)
  game.proj = perspective(r, aspect, 0.125f, sky)

  #const field_width = 10f
  #game.proj = ortho(aspect * -field_width, aspect * field_width, -field_width, field_width, 0f, sky) # In world coordinates

proc reset_view*(game: var Game) =
  game.update_fov()
  game.update_camera()
  game.camera.pan.vel = vec3f(0,0,0)

proc reset_player*(game: var Game) =
  let player_top = game.level.origin.y.float
  game.player.mesh.reset()
  game.player.mesh.scale = vec3f(1,1,1)
  game.player.mesh.pos += vec3f(0.5, 0.5, 0.5)
  game.player.mesh.pos.y = player_top

proc follow_player*(game: var Game) =
  let coord = game.player.coord
  #let target = game.player.mesh.pos# * 0.5f

  let y = (game.player.mesh.pos.y - game.level.origin.y.float) * 0.5
  game.camera.pan.target = vec3f( coord.x, y, coord.z )

  #let ly = target.y
  if game.goal:
    return

proc toggle_pause*(game: var Game) =
  game.paused = not game.paused
  if game.paused:
    game.mouse_mode = MouseOff
    game.update_mouse_mode()

proc pan_stop(game: var Game) =
  game.camera.pan.acc = vec3f(0f,0f,0f)


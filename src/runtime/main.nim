
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


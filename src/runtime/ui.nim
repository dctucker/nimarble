
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


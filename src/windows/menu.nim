
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


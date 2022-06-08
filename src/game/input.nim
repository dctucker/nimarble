
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


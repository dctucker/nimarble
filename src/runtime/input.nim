
let game_keymap = {
  GLFWKey.Up           : pan_up            ,
  GLFWKey.Down         : pan_down          ,
  GLFWKey.Left         : pan_left          ,
  GLFWKey.Right        : pan_right         ,
  GLFWKey.PageUp       : pan_in            ,
  GLFWKey.PageDown     : pan_out           ,
  GLFWKey.Home         : pan_ccw           ,
  GLFWKey.End          : pan_cw            ,
  GLFWKey.LeftBracket  : prev_level        ,
  GLFWKey.RightBracket : next_level        ,
  GLFWKey.F            : follow            ,
  GLFWKey.R            : do_reset_player   ,
  GLFWKey.X            : do_respawn        ,
  GLFWKey.W            : toggle_wireframe  ,
  GLFWKey.P            : pause             ,
  GLFWKey.Period       : step_frame        ,
  GLFWKey.L            : toggle_mouse_lock ,
  GLFWKey.G            : toggle_god        ,
  GLFWKey.E            : focus_editor      ,
  GLFWKey.A            : animate_step      ,
  GLFWKey.Escape       : toggle_all        ,
}.toOrderedTable

let game_keymap_shift = {
  GLFWKey.Slash        : toggle_keymap     ,
}.toOrderedTable

let game_keymap_command = {
  GLFWKey.K1           : choose_level      ,
  GLFWKey.K2           : choose_level      ,
  GLFWKey.K3           : choose_level      ,
  GLFWKey.K4           : choose_level      ,
  GLFWKey.K5           : choose_level      ,
  GLFWKey.K6           : choose_level      ,
  GLFWKey.K7           : choose_level      ,
  GLFWKey.K8           : choose_level      ,
  GLFWKey.K9           : choose_level      ,
  #GLFWKey.R            : reload_level      ,
  GLFWKey.Q            : do_quit           ,
}.toOrderedTable

proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  let press = (action != GLFWRelease)

  if editor.focused and press:
    if editor.handle_key(key, mods):
      return

  game.recent_input = key
  game.window = window
  if (mods and GLFWModShift) != 0:
    if game_keymap_shift.hasKey key:
      game_keymap_shift[key].callback(game, press)
  elif (mods and GLFWModControl) != 0 or (mods and GLFWModSuper) != 0:
    if game_keymap_command.hasKey key:
      game_keymap_command[key].callback(game, press)
  else:
    if game_keymap.hasKey key:
      game_keymap[key].callback(game, press)

proc rotate_mouse(mouse: Vec3f): Vec3f =
  const th = radians(45f)
  const rot_matrix = mat2f(vec2f(cos(th), sin(th)), vec2f(-sin(th), cos(th)))
  let m = rot_matrix * vec2f(mouse.x, mouse.y)
  result = vec3f(m.x, m.y, mouse.z)

proc mouseProc(window: GLFWWindow, xpos, ypos: cdouble): void {.cdecl.} =
  if game.mouse_mode == MouseOff:
    return
  let mid = middle()
  if not game.paused:
    window.setCursorPos mid.x, mid.y
  mouse.x = -(mid.x - xpos)
  mouse.y =  (mid.y - ypos)
  #echo mouse.x, "\r" #, ",", mouse.y

proc scrollProc(window: GLFWWindow, xoffset, yoffset: cdouble): void {.cdecl.} =
  const wheel_ratio = 1.0 / 41.0
  mouse.z = yoffset * wheel_ratio
  if game.mouse_mode == MouseOff:
    if igGetIO().wantCaptureMouse:
      return
    if yoffset < 0:
      pan_cw.callback(game, true)
    elif yoffset > 0:
      pan_ccw.callback(game, true)

  #var dir = vec3f(0,0,1)
  #var axis = player.mesh.normal.cross(dir).normalize()
  #let angle = mouse.z
  #player.mesh.rot = normalize(quatf(axis, angle) * player.mesh.rot)

  #game.camera.fov -= mouse.z
  #game.update_camera()
  #game.update_fov()


proc poll_joystick*(game: var Game) =
  if joystick.id == -1: return

  const xbox = 2 # TODO select which joystick
  var n_axes: int32
  var ax = glfwGetJoystickAxes(xbox, n_axes.addr)
  if n_axes == 6:
    joystick.id = xbox
  else:
    joystick.id = -1
    return
  var axes = cast[ptr UncheckedArray[float32]](ax)
  joystick.left_thumb.x  = axes[0]
  joystick.left_thumb.y  = axes[1]
  joystick.right_thumb.x = axes[2]
  joystick.right_thumb.y = axes[3]
  joystick.triggers.x    = axes[4]
  joystick.triggers.y    = axes[5]

  var n_buttons: int32
  var b = glfwGetJoystickButtons(xbox, n_buttons.addr)
  var buttons = cast[ptr UncheckedArray[uint8]](b)
  joystick.buttons.x      = buttons[ 3] == GLFW_PRESS.uint8
  joystick.buttons.y      = buttons[ 4] == GLFW_PRESS.uint8
  joystick.buttons.a      = buttons[ 0] == GLFW_PRESS.uint8
  joystick.buttons.b      = buttons[ 1] == GLFW_PRESS.uint8
  joystick.buttons.back   = buttons[ 0] == GLFW_PRESS.uint8
  joystick.buttons.lb     = buttons[ 6] == GLFW_PRESS.uint8
  joystick.buttons.rb     = buttons[ 7] == GLFW_PRESS.uint8
  joystick.buttons.lthumb = buttons[13] == GLFW_PRESS.uint8
  joystick.buttons.rthumb = buttons[14] == GLFW_PRESS.uint8
  joystick.buttons.start  = buttons[11] == GLFW_PRESS.uint8
  joystick.buttons.xbox   = buttons[12] == GLFW_PRESS.uint8
  joystick.buttons.up     = buttons[15] == GLFW_PRESS.uint8
  joystick.buttons.right  = buttons[16] == GLFW_PRESS.uint8
  joystick.buttons.down   = buttons[17] == GLFW_PRESS.uint8
  joystick.buttons.left   = buttons[18] == GLFW_PRESS.uint8
  #[
  for n in 0 ..< n_buttons:
    if buttons[n] == GLFW_PRESS.cuchar: stdout.write n
    else: stdout.write "  "
  echo ""
  ]#


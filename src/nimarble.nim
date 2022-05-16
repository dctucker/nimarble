{. warning[HoleEnumConv]:off .}

import std/tables
import nimgl/[glfw,opengl]
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
import glm
import wrapper

import types
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
  log_frame_time frame_time

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
  GLFWKey.S            : step_frame        ,
  GLFWKey.L            : toggle_mouse_lock ,
  GLFWKey.G            : toggle_god        ,
  GLFWKey.E            : focus_editor      ,
  GLFWKey.Escape       : toggle_all        ,
  GLFWKey.Q            : do_quit           ,
  GLFWKey.Slash        : toggle_keymap     ,
  #GLFWKey.O            : reload_level      ,
}.toOrderedTable

proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  let press = (action != GLFWRelease)

  if editor.focused and press:
    if editor.handle_key(key, mods):
      return

  if game_keymap.hasKey key:
    game.window = window
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
    if yoffset < 0:
      pan_cw.callback(game, true)
    elif yoffset > 0:
      pan_ccw.callback(game, true)

  #var dir = vec3f(0,0,1)
  #var axis = game.player.mesh.normal.cross(dir).normalize()
  #let angle = mouse.z
  #game.player.mesh.rot = normalize(quatf(axis, angle) * game.player.mesh.rot)

  #game.camera.fov -= mouse.z
  #game.update_camera()
  #game.update_fov()

proc poll_joystick*(game: var Game) =
  if joystick.id == -1: return

  const xbox = 2 # TODO
  var n_axes: int32
  var ax = glfwGetJoystickAxes(xbox, n_axes.addr)
  echo n_axes
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

proc setup_glfw(): GLFWWindow =
  doAssert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_FALSE)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFW_FALSE);

  #(width, height) = display_size()
  let w = glfwCreateWindow(width, height, "Nimarble", nil, nil)
  doAssert w != nil

  w.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorDisabled
  #w.setCursor GLFWCursorDisabled
  if glfwRawMouseMotionSupported() == GLFW_TRUE:
    w.setInputMode GLFW_RAW_MOUSE_MOTION, GLFW_TRUE
  discard w.setKeyCallback(keyProc)
  discard w.setCursorPosCallback(mouseProc)
  discard w.setScrollCallback(scrollProc)
  w.makeContextCurrent()
  let mid = middle()
  w.setCursorPos mid.x, mid.y
  #w.setWindowOpacity(0.9)
  result = w

  when defined(windows):
    var hwnd = w.getWin32Window()
    doAssert hwnd != nil

proc setup_opengl() =
  doAssert glInit()

  glClearColor(0f,0f,0.1f, 1f)
  glClear(GL_COLOR_BUFFER_BIT)
  glEnable GL_DEPTH_TEST # Enable depth test
  glDepthFunc GL_LESS    # Accept fragment if it closer to the camera than the former one

  glEnable GL_BLEND
  glBlendFunc GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA
  glShadeModel GL_FLAT

proc info_player =
  let level = game.get_level()
  let coord = game.player.mesh.pos.rotate_coord
  if app.show_player:
    igSetNextWindowSize(ImVec2(x:300f, y:400f))
    if igBegin("player"):
      #var lateral = player.pos.xz.length()
      #igSliderFloat "lateral_d", lateral.addr     , -sky, sky
      igDragFloat3 "pos"     , game.player.mesh.pos.arr   , 0.125, -sky, sky
      igDragFloat3 "vel"     , game.player.mesh.vel.arr   , 0.125, -sky, sky
      igDragFloat3 "acc"     , game.player.mesh.acc.arr   , 0.125, -sky, sky
      igDragFloat4 "rot"     , game.player.mesh.rot.arr   , 0.125, -sky, sky
      #igSliderFloat3 "normal" , game.player.mesh.normal.arr, -1.0, 1.0
      igSliderFloat3 "respawn_pos" , game.player.respawn_pos.arr  , -sky, sky

      igSpacing()
      igSeparator()
      igSpacing()

      var m0 = ($level.mask_at(coord.x, coord.z)).cstring
      var m1 = ($level.mask_at(coord.x+1, coord.z)).cstring
      var m2 = ($level.mask_at(coord.x, coord.z+1)).cstring
      igText(m0, 2)
      igSameLine()
      igText(m1)
      igSameLine()
      igText(m2)

      var sl = level.slope(coord.x, coord.z)
      igDragFloat3 "slope"     , sl.arr         , -sky, sky

      var respawns = game.respawns.int32
      igSliderInt    "respawns"     , respawns.addr, 0.int32, 10.int32
      igCheckBox     "following"    , game.following.addr
      igCheckBox     "wireframe"    , game.wireframe.addr
      igCheckBox     "god"          , game.god.addr
      igSliderInt    "level"        , game.level.addr, 1.int32, n_levels.int32 - 1

      #igText("average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
    igEnd()

  if app.show_cube_points:
    if igBegin("cube point"):
      let (i,j) = level.xlat_coord(coord.x.floor, coord.z.floor)
      if not level.has_coord( i,j ): igEnd() ; return

      var p0 = level.cube_point(i, j, 23)
      var p1 = level.cube_point(i, j, 24)
      var p2 = level.cube_point(i, j, 25)
      var p3 = level.cube_point(i, j, 26)

      igDragFloat3 "pos0", p0.pos.arr
      igDragFloat3 "pos1", p1.pos.arr
      igDragFloat3 "pos2", p2.pos.arr
      igDragFloat3 "pos3", p3.pos.arr

      igColorEdit4 "color0", p0.color.arr
      igColorEdit4 "color1", p1.color.arr
      igColorEdit4 "color2", p2.color.arr
      igColorEdit4 "color3", p3.color.arr

      igDragFloat3 "normal0", p0.normal.arr
      igDragFloat3 "normal1", p1.normal.arr
      igDragFloat3 "normal2", p2.normal.arr
      igDragFloat3 "normal3", p3.normal.arr
    igEnd()

proc sync_editor =
  let coord = game.player.mesh.pos.rotate_coord
  if not editor.focused:
    editor.col = editor.level.origin.x + coord.x.floor.int
    editor.row = editor.level.origin.z + coord.z.floor.int
  else:
    game.player.mesh.pos.x = editor.col.float - editor.level.origin.x.float
    game.player.mesh.pos.z = editor.row.float - editor.level.origin.z.float
  if app.show_editor: editor.draw()

proc `or`*(f1, f2: ImGuiWindowFlags): ImGuiWindowFlags =
  return ImGuiWindowFlags( f1.ord or f2.ord )

proc draw_imgui =
  let level = game.get_level()
  igPushFont( small_font )

  app.main_menu()
  info_player()
  if app.show_actors: level.actors.info_window()
  if app.show_fixtures: level.fixtures.info_window()

  if app.show_camera:
    if game.camera.info_window():
      game.view.mat = lookAt( game.camera.pos, game.camera.target, game.camera.up )
      game.update_camera()

  if app.show_light:
    if game.light.info_window():
      game.light.update()

  if app.show_masks:
    XX.info_window()
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
      draw_keymap(editor_keymap, editor_keymap_shift, editor_keymap_command)
    else:
      draw_keymap(game_keymap)

  if app.show_joystick:
    joystick.info_window()

  igRender()
  igOpenGL3RenderDrawData(igGetDrawData())

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()

proc god: bool = return game.god or editor.focused

proc render(mesh: var Mesh, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  mesh.mvp.update game.proj * game.view.mat.translate(-game.pan.pos) * mesh.model.mat
  mesh.model.update
  mesh.program.use()
  mesh.vert_vbo.apply 0
  mesh.color_vbo.apply 1
  mesh.norm_vbo.apply 2
  if mesh.elem_vbo.n_verts > 0:
    mesh.elem_vbo.draw_elem kind
  else:
    mesh.vert_vbo.draw kind
  glDisableVertexAttribArray 0
  glDisableVertexAttribArray 1

method render[T](piece: var T) =
  var mesh = piece.mesh

  mesh.model.mat = mat4(1.0f)
    .translate(mesh.pos * vec3f(1,level_squash,1)) * mesh.rot.mat4f

  glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
  mesh.render        GL_TRIANGLE_STRIP

proc main =
  editor = Editor(cursor_data: true, cursor_mask: true, stamp: Stamp(width:0, height: 0))
  game = newGame()
  let w = setup_glfw()

  setup_opengl()
  setup_imgui(w)

  game.init()
  game.light.update()

  proc physics(game: var Game, mesh: var Mesh) {.inline.} =
    const mass = player_radius
    #let gravity = if game.level == 5: -98f else: 98f
    const gravity = -98f
    const max_vel = vec3f( 15f, -gravity * 0.5f, 15f )
    let level = game.get_level()
    if not game.goal:
      level.clock += 1
      level.clock = level.clock mod 3600
    let coord = mesh.pos.rotate_coord
    let x = coord.x
    let z = coord.z
    let bh = mesh.pos.y
    let fh = level.point_height(x, z)
    let cur_mask = level.mask_at(x,z)
    #stdout.write "\27[K"

    for actor in level.actors.mitems:
      game.physics(actor, dt)

    mesh.model.mat = mat4(1.0f)
      .translate(vec3f(0, player_radius,0))
      .translate(mesh.pos * vec3f(1,level_squash,1)) * mesh.rot.mat4f

    if game.player.animate(t): return

    # figure out if we're in mortal danger
    game.player.dead = mesh.pos.y < 10f or (mesh.acc.xz.length == 0f and mesh.vel.y <= -max_vel.y)
    for actor in level.actors.mitems:
      if actor.kind == EA:
        if (actor.mesh.pos - game.player.mesh.pos).length < 1f:
          actor.mesh.pos = game.player.mesh.pos
          game.player.animate Dissolve, t + 1f
          return

    let ramp = level.slope(x,z) * level_squash * level_squash
    let thx = arctan(ramp.x)
    let thz = arctan(ramp.z)
    let cosx = cos(thx)
    let cosz = cos(thz)
    let sinx = sin(thx)
    let sinz = sin(thz)
    var ramp_a = vec3f( -ramp.x, sinx + sinz, -ramp.z ) * gravity
    if game.level == 6: # works for ramps but not walls
      ramp_a = vec3f( ramp.x, sinx + sinz, ramp.z ) * gravity

    var icy = level.around(IC, x,z)
    var copper = level.around(CU, x,z)
    var traction: float
    if bh - fh > 0.25:
      traction = 0f
    else:
      traction = 1f

    if god():
      ramp_a *= 0
      traction = 1f

    var safe: bool
    let flat = ramp.length == 0
    let nonzero = level.point_height(x.floor, z.floor) > 0f

    safe = flat and nonzero and cur_mask == XX
    safe = safe and not icy and not copper
    safe = safe and game.safe
    if safe:
      game.player.respawn_pos = vec3f(mesh.pos.x.floor, mesh.pos.y, mesh.pos.z.floor)

    const max_acc = 50f
    var m = vec3f(0,0,0)
    if not game.paused and not game.goal and not icy and not copper:
      m = rotate_mouse(mouse)
      if m.length > max_acc:
        m = m.normalize() * max_acc
      if joystick.left_thumb.length > 0.05:
        m += vec3f(joystick.left_thumb.x, -joystick.left_thumb.y, 0).rotate_mouse * 40

    mesh.acc *= 0
    mesh.acc += mass * vec3f(m.x, 0, -m.y) * traction  # mouse motion
    mesh.acc += vec3f(0, (1f-traction) * gravity, 0)   # free fall
    mesh.acc += ramp_a * traction

    if god(): mesh.acc.y = gravity * 0.125

    let lateral_dir = mesh.vel.xz.normalize()
    let lateral_vel = mesh.vel.xz.length()
    let vertical_vel = mesh.vel.y

    mesh.vel.x = clamp(mesh.vel.x + dt * mesh.acc.x, -max_vel.x, max_vel.x)
    mesh.vel.y = clamp(mesh.vel.y + dt * mesh.acc.y, -max_vel.y * 1.5f, max_vel.y)
    mesh.vel.z = clamp(mesh.vel.z + dt * mesh.acc.z, -max_vel.z, max_vel.z)
    if icy:
      if mesh.vel.length * lateral_vel > 0f:
        let dir = normalize(mesh.vel.xz.normalize() + lateral_dir)
        mesh.vel = vec3f(dir.x, 0, dir.y) * lateral_vel
        mesh.vel.y = max_vel.y * -0.5

    mesh.pos += mesh.vel * dt
    mesh.pos.y = clamp(mesh.pos.y, fh, sky)

    # rotation animation
    if (mesh.vel * vec3f(1,0,1)).length > 0:
      var dir = -mesh.vel.normalize()
      var axis = mesh.normal.cross(dir).normalize()
      let angle = mesh.vel.xz.length * dt / 0.5f / Pi / player_radius
      let quat = quatf(axis, angle)
      if quat.length > 0:
        mesh.rot = normalize(quat * mesh.rot)

    const brake = 0.986
    if not icy and not copper:
      mesh.vel  *= brake

    mouse *= 0

    if level.around(TU,x,z):
      mesh.vel.y = clamp(mesh.vel.y, -max_vel.y, max_vel.y)

    if god(): return # a god neither dies nor achieves goals

    if level.around(IN,x,z):
      let dest = level.find_closest(OU, x, z)
      if dest.length != 0:
        game.player.teleport_dest = dest
        game.player.animation_time = t + 1.2f
        game.player.animation = Teleport
        game.player.mesh.pos = game.player.teleport_dest
        #game.player.respawn_pos = game.player.mesh.pos

    if game.player.dead:
      game.player.animate(Respawn, t + 1f)
      game.respawns += 1

    if game.goal:
      mesh.vel *= 0.97f
      if event_time == 0:
        event_time = time
      if time - event_time > 3.0f:
        game.goal = false
        event_time = 0
        next_level.callback(game, true)
    else:
      game.goal = game.goal or cur_mask == GG

  # main loop
  while not w.windowShouldClose():
    var level = game.get_level()
    var floor_plane = level.floor_plane
    var actors = level.actors
    var fixtures = level.fixtures
    time = glfwGetTime()
    dt = time - t
    t = time

    fps_count()

    if game.paused and game.frame_step:
      game.physics(game.player.mesh)
      game.frame_step = false
    elif not game.paused:
      game.physics(game.player.mesh)

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

    if not game.wireframe:
      glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
      glEnable           GL_POLYGON_OFFSET_FILL
      glPolygonOffset 1f, 1f
      floor_plane.render GL_TRIANGLE_STRIP
      glDisable          GL_POLYGON_OFFSET_FILL

    glPolygonMode        GL_FRONT_AND_BACK, GL_LINE
    floor_plane.render   GL_TRIANGLE_STRIP

    glPolygonMode        GL_FRONT_AND_BACK, GL_FILL

    if game.player.visible:
      game.player.mesh.render

    for actor in actors.mitems:
      actor.render()

    for fixture in fixtures.mitems:
      fixture.render()

    imgui_frame()

    w.swapBuffers()
    fps_count()
    game.poll_joystick()
    glfwPollEvents()

  w.cleanup()

main()

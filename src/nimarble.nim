{. warning[HoleEnumConv]:off .}

#import nimprof
import std/tables
import nimgl/[glfw,opengl]
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
import glm
import wrapper

import pieces
import types
import masks
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
  logs.frame_time.log frame_time

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

  glClearColor 0f, 0f, 0.1f, 1f
  glClear      GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
  glEnable     GL_DEPTH_TEST
  glDepthFunc  GL_LESS       # Accept fragment if it closer to the camera than the former one

  glEnable     GL_BLEND
  glBlendFunc  GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA
  #glShadeModel GL_FLAT

  glEnable     GL_LINE_SMOOTH
  glLineWidth  2f

  #glEnable    GL_CULL_FACE
  #glCullFace  GL_BACK
  #glFrontFace GL_CW

proc info_player =
  igSetNextWindowSize(ImVec2(x:300f, y:400f))
  if igBegin("player"):
    var player = game.player
    var level = game.level
    var coord = player.coord
    #var lateral = player.pos.xz.length()
    #igSliderFloat "lateral_d", lateral.addr     , -sky, sky
    igDragFloat3 "pos"     , player.mesh.pos.arr   , 0.125, -sky, sky
    igDragFloat3 "vel"     , player.mesh.vel.arr   , 0.125, -sky, sky
    igDragFloat3 "acc"     , player.mesh.acc.arr   , 0.125, -sky, sky
    igDragFloat4 "rot"     , player.mesh.rot.arr   , 0.125, -sky, sky
    #igSliderFloat3 "normal" , player.mesh.normal.arr, -1.0, 1.0
    igSliderFloat3 "respawn_pos" , player.respawn_pos.arr  , -sky, sky

    var respawns = game.respawns.int32
    igSliderInt    "respawns"     , respawns.addr, 0.int32, 10.int32

    var anim_time = player.animation_time.float32
    igSliderFloat    "player clock" , anim_time.addr, 0f, 1f
    var anim = "player animation" & $player.animation
    igText    anim.cstring

    igSpacing()
    igSeparator()
    igSpacing()

    var m0 = ($level.masks_at(coord.x, coord.z)).cstring
    var m1 = ($level.masks_at(coord.x+1, coord.z)).cstring
    var m2 = ($level.masks_at(coord.x, coord.z+1)).cstring
    igText(m0, 2)
    igSameLine()
    igText(m1)
    igSameLine()
    igText(m2)

    var sl = level.slope(coord.x, coord.z)
    igDragFloat3 "slope"     , sl.arr         , -sky, sky

    igSpacing()
    igSeparator()
    igSpacing()

    var clock = level.clock.float32
    igSliderFloat  "clock"        , clock.addr, 0f, 1f

    var phase = level.phase.int32
    igSliderInt    "phase"        , phase.addr, P1.int32, P4.int32

    if igColorEdit3( "color"      , level.color.arr ):
      level.reload_colors()

    igCheckBox     "following"    , game.following.addr
    igCheckBox     "wireframe"    , game.wireframe.addr
    igCheckBox     "god"          , game.god.addr
    igSliderInt    "level #"      , game.level_number.addr, 1.int32, n_levels.int32 - 1

    #igText("average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
  igEnd()

proc compute_model(mesh: var Mesh) =
  mesh.model.mat = mat4(1.0f)
    .translate(mesh.pos * vec3f(1,level_squash,1))
    .translate(mesh.translate)
    .scale(mesh.scale) * mesh.rot.mat4f

proc render*(game: var Game, mesh: var Mesh) =
  mesh.mvp.mat = game.proj * game.view.mat.translate(-game.camera.pan.pos) * mesh.model.mat
  mesh.render()

proc render[T: Piece](piece: var T) =
  var mesh = piece.mesh
  mesh.compute_model()

  game.render(mesh)

proc render[T: Cursor](cursor: var T) =
  cursor.mesh.compute_model()
  cursor.mesh.wireframe = true
  game.render cursor.mesh
  cursor.mesh.wireframe = false
  game.render cursor.mesh
  cursor.phase.inc

  var scale = 1.03125 + 0.125 * ((cursor.phase mod 40) - 20).abs.float / 20f
  cursor.mesh.scale.xz = vec2f(scale)

proc sync_editor =
  var player = game.player
  var mesh = player.mesh
  var cursor = editor.cursor.mesh
  let coord = player.coord
  if not editor.focused:
    editor.col = editor.level.origin.x + coord.x.floor.int
    editor.row = editor.level.origin.z + coord.z.floor.int
  else:
    mesh.pos.x = editor.col.float - editor.level.origin.x.float
    mesh.pos.z = editor.row.float - editor.level.origin.z.float
    cursor.pos = mesh.pos
    editor.cursor.cube = editor.level.map[editor.row, editor.col].cube
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

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()

proc god: bool = return game.god or editor.focused

proc physics[T](game: var Game, pieces: var T, dt: float) =
  for actor in pieces.mitems:
    game.physics(actor, dt)

proc apply_roll_rotation(player: var Player) =
  var mesh = player.mesh
  if (mesh.vel * vec3f(1,0,1)).length > 0:
    var dir = -mesh.vel.normalize()
    var axis = mesh.normal.cross(dir).normalize()
    var angle = mesh.vel.xz.length * dt / 0.5f / Pi / player_radius
    if player.animation == Stun:
      angle *= 0.25f

    let quat = quatf(axis, angle)
    if quat.length > 0:
      mesh.rot = normalize(quat * mesh.rot)

const mass = player_radius
const gravity = -98f
const max_acc = 50f
const max_vel = vec3f( 15f, -gravity * 0.5f, 15f )
const air_brake = 255/256f
const min_air = 1/32f

var cur_masks: set[CliffMask]
var air, last_air: float32
var last_acc: Vec3f

proc no_air =
  last_air = 0
  air = 0

proc apply_air(player: var Player, air: float) =
  var mesh = player.mesh
  if air > min_air:
    mesh.vel.y = clamp(mesh.vel.y + dt * mesh.acc.y, -max_vel.y * 1.5f, max_vel.y)
    last_air = max(last_air, air)
  else:
    mesh.vel.y *= clamp( air / min_air, 0.0, air_brake )

proc detect_impact_damage(player: var Player, air: float) =
  var mesh = player.mesh
  if air > min_air: return
  if last_air < 1f: return
  if last_acc.y.abs < gravity.abs: return

  echo "impact ", mesh.vel.y, " last air ", last_air
  if last_air > 2f: # impact velocity would be >13f
    player.animate Stun, t + 1.5f
  if last_air > 4f: # impact velocity woulde be >26f
    player.animate Break, t + 2f
  last_acc.y *= 0
  no_air()

proc detect_actor_collision(player: var Player, actors: var ActorSet): bool =
  for actor in actors.mitems:
    if (actor.mesh.pos - player.mesh.pos).length < 1f:
      if actor.mesh.scale.length < 1f:
        actor.mesh.scale.y = 0.1f
        continue
      if actor.kind == EA:
        actor.mesh.pos = player.mesh.pos
        player.animate Dissolve, t + 1f
        return true

proc detect_fall_damage(player: var Player) =
  var mesh = player.mesh
  if mesh.pos.y < 10f:
    player.die "fell off"
  if mesh.acc.xz.length == 0f and mesh.vel.y <= -max_vel.y:
    player.die "terminal velocity"

var beats = 0
var traction: float
var ramp, ramp_a: Vec3f
var rail, icy, sandy, oily, copper, stunned, portal: bool

proc get_input_vector(game: Game): Vec3f =
  if game.paused or game.goal or icy or copper:
    return vec3f(0,0,0)
  result = rotate_mouse(mouse)
  if result.length > max_acc:
    result = result.normalize() * max_acc
  if joystick.left_thumb.length > 0.05:
    result += vec3f(joystick.left_thumb.x, -joystick.left_thumb.y, 0).rotate_mouse * 40
  mouse *= 0

proc calculate_acceleration(mesh: var Mesh, input_vector: Vec3f) =
  if mesh.acc.y != 0:
    last_acc = mesh.acc
  mesh.acc *= 0
  mesh.acc += mass * vec3f(input_vector.x, 0, -input_vector.y) * traction
  if not sandy and not oily:
    mesh.acc += vec3f(0, (1f-traction) * gravity, 0)   # free fall

  mesh.acc += ramp_a * traction
  if god(): mesh.acc.y = gravity * 0.125

proc find_closest(game: Game, mask: CliffMask): Vec3f =
  var coord = game.player.coord
  return game.level.find_closest(mask, coord.x, coord.z)

proc maybe_teleport(game: var Game) =
  var player = game.player
  if cur_masks.has(IN) and air < 0.0625f:
    let dest = game.find_closest OU
    if dest.length != 0:
      player.teleport_dest = dest
      player.animate Teleport, t + 1.2f
      no_air()

proc maybe_respawn(game: var Game) =
  var player = game.player
  if player.dead:
    echo "ur ded"
    player.dead = false
    player.animate Respawn, t + 1f
    game.respawns += 1
    no_air()

proc maybe_complete(game: var Game) =
  var mesh = game.player.mesh
  if game.goal:
    mesh.vel *= 0.97f
    if event_time == 0:
      event_time = time
    if time - event_time > 3.0f:
      game.goal = false
      event_time = 0
      next_level.callback(game, true)
  else:
    game.goal = game.goal or cur_masks.has GG

proc update_state(game: var Game) =
  rail    = cur_masks.has GR
  icy     = cur_masks.has IC
  sandy   = cur_masks.has SD
  oily    = cur_masks.has OI
  copper  = cur_masks.has CU
  portal  = (cur_masks * {TU,IN,OU}).card > 0
  stunned = game.player.animation == Stun

  traction = 1.0
  if god():
    air = 0
    last_air = 0
    ramp_a *= 0
  elif air > 0.25: traction *= 0f
  else:
    if sandy   : traction *= 0.5
    if oily    : traction *= 0.75f
    if stunned : traction *= 0.125f


proc physics(game: var Game) =
  var player = game.player
  var mesh = player.mesh
  var level = game.level

  if not game.goal:
    level.tick(t)

  game.physics(level.actors, dt)

  beats.inc
  if beats mod 2 == 0:
    game.physics(level.fixtures, dt)

  if player.animate(t): return

  if not god():
    if player.detect_actor_collision(level.actors): return
    player.detect_fall_damage()

  let x  = player.coord.x
  let z  = player.coord.z

  ramp = level.slope(x,z) * level_squash * level_squash
  let thx = arctan(ramp.x)
  let thz = arctan(ramp.z)
  #let cosx = cos(thx)
  #let cosz = cos(thz)
  let sinx = sin(thx)
  let sinz = sin(thz)

  ramp_a = vec3f( -ramp.x, sinx + sinz, -ramp.z ) * gravity
  if game.level_number == 6: # works for ramps but not walls
    ramp_a = vec3f( ramp.x, sinx + sinz, ramp.z ) * gravity

  cur_masks = level.masks_at(x,z)
  game.update_state()

  if rail:
    let fixture = level.fixture_at(x,z)
    if fixture != nil and fixture.mesh != nil:
      let normal = fixture.normal(player)
      mesh.vel.xz = mesh.vel.reflect(normal).xz

  let bh = mesh.pos.y
  let floor_height = level.point_height(x, z)
  air = bh - floor_height

  let flat = ramp.length == 0
  let nonzero = level.point_height(x.floor, z.floor) > 0f

  let safe = game.safe and
    flat       and
    nonzero    and
    not icy    and
    not copper
  if safe:
    player.respawn_pos = vec3f(mesh.pos.x.floor, mesh.pos.y, mesh.pos.z.floor)

  var m = game.get_input_vector()
  mesh.calculate_acceleration(m)

  let lateral_dir = mesh.vel.xz.normalize()
  let lateral_vel = mesh.vel.xz.length()

  mesh.vel.xz = clamp(mesh.vel.xz + dt * mesh.acc.xz, -max_vel.xz, max_vel.xz)

  player.apply_air(air)
  if not portal:
    player.detect_impact_damage(air)

  if icy:
    if mesh.vel.length * lateral_vel > 0f:
      let dir = normalize(mesh.vel.xz.normalize() + lateral_dir)
      mesh.vel = vec3f(dir.x, 0, dir.y) * lateral_vel
      mesh.vel.y = max_vel.y * -0.5

  mesh.pos += mesh.vel * dt
  mesh.pos.y = clamp(mesh.pos.y, floor_height, sky)

  player.apply_roll_rotation()

  const brake = 0.986
  if not ( icy or copper or oily ):
    mesh.vel *= brake

  if cur_masks.has TU:
    mesh.vel.y = clamp(mesh.vel.y, -max_vel.y, max_vel.y)

  logs.player_vel_y.log mesh.vel.y
  logs.player_acc_y.log mesh.acc.y
  logs.air.log air

  if god(): return # a god neither dies nor achieves goals

  game.maybe_teleport()
  game.maybe_respawn()
  game.maybe_complete()

proc visible*(p: Player): bool =
  return p.animation != Teleport

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

    imgui_frame()

    w.swapBuffers()
    fps_count()

    game.poll_joystick()
    glfwPollEvents()

  w.cleanup()

#start_level = 5.int32
main()

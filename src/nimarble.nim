import os
import std/tables
import std/with
import strutils
import nimgl/[glfw,opengl]
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
import glm

import types
import models
import leveldata
import contrib/heightmap

const vert_source = readFile("src/shaders/player.vert")
var verts = vert_source.cstring

const frag_source = readFile("src/shaders/player.frag")
var frags = frag_source.cstring

const geom_source = readFile("src/shaders/player.geom")
var geoms = "".cstring

if os.getEnv("CI") != "": quit()

var width, height: int32
width = 1600
height = 1200
var aspect: float32 = width / height

proc middle(): Vec2f = vec2f(width.float * 0.5f, height.float * 0.5f)

var game: Game
var mouse: Vec3f

const level_squash = 0.5f
const start_level = 1

proc update_camera(game: Game) =
  let level = game.get_level()

  game.camera_target = vec3f( 0, level.origin.y.float * level_squash, 0 )
  game.camera_pos = vec3f( 20, game.camera_target.y + 20, 20 )
  game.camera_up = vec3f( 0f,  1.0f,  0f )
  #let target = vec3f( 10, 0, 10 )
  #let pos = vec3f( level.origin.z.float * 2, 0, level.origin.z.float * 2)
  echo game.camera_target
  game.view = lookAt( game.camera_pos, game.camera_target, game.camera_up )

const field_width = 10f
proc update_fov(game: Game) =
  let r: float32 = radians(game.fov)
  game.proj = perspective(r, aspect, 0.125f, sky)
  #game.proj = ortho(aspect * -field_width, aspect * field_width, -field_width, field_width, 0f, sky) # In world coordinates

proc reset_view(game: Game) =
  game.update_fov()
  game.update_camera()
  game.pan_vel = vec3f(0,0,0)

proc reset_mesh(mesh: Mesh) =
  mesh.pos = vec3f(0f, 0f, 0f)
  mesh.vel = vec3f(0,0,0)
  mesh.acc = vec3f(0,0,0)
  mesh.rot = quatf(vec3f(0,-1,0),0).normalize
  mesh.normal = vec3f(0,-1,0)
  #mesh.rvel = vec3f(0,0,0)
  #mesh.racc = vec3f(0,0,0)

proc reset_player(game: Game) =
  let player_top = game.get_level().origin.y.float
  game.player.mesh.reset_mesh()
  game.player.mesh.pos.y = player_top

proc do_reset_player(press: bool) =
  if press:
    game.reset_player()

proc respawn(press: bool) =
  if press:
    game.reset_player()
    game.player.mesh.pos = game.respawn_pos
    game.reset_view()

proc rotate_coord(v: Vec3f): Vec3f =
  let v4 = mat4f(1f).translate(v).rotateY(radians(45f))[3]
  result = vec3f(v4.x, v4.y, v4.z)

proc follow_player(game: Game) =
  let level = game.get_level()
  let coord = game.player.mesh.pos.rotate_coord
  let target = game.player.mesh.pos# * 0.5f

  let y = (game.player.mesh.pos.y - level.origin.y.float) * 0.5
  game.pan_target = vec3f( coord.x, y, coord.z )
  if game.goal:
    return

proc update_mouse_lock =
  if not game.mouse_lock:
    game.window.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorNormal
  else:
    let mid = middle()
    game.window.setCursorPos mid.x, mid.y
    mouse *= 0
    game.window.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorDisabled

proc toggle_mouse_lock(press: bool) =
  if not press:
    return
  game.mouse_lock = not game.mouse_lock
  update_mouse_lock()

proc toggle_pause(w: GLFWWindow) =
  game.paused = not game.paused
  if game.paused:
    game.mouse_lock = false
    update_mouse_lock()

proc init_player(game: var Game) =
  game.player.mesh = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, sphere),
    color_vbo: newVBO(4, sphere_colors),
    elem_vbo: newElemVBO(sphere_index),
    program: newProgram(frags, verts, geoms),
  )
  game.reset_player()

  game.player.mesh.model  = mat4(1.0f)
  game.player.mesh.mvp    = game.proj * game.view.translate(-game.pan) * game.player.mesh.model
  game.player.mesh.matrix = game.player.mesh.program.newMatrix(game.player.mesh.mvp, "MVP")


proc init_floor_plane(game: Game) =
  let level = game.get_level()
  if level.floor_plane != nil:
    return
  load_level game.level
  level.floor_plane = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, level.floor_verts),
    color_vbo: newVBO(4, level.floor_colors),
    elem_vbo: newElemVBO(level.floor_index),
    program: game.player.mesh.program,
  )
  level.floor_plane.model = mat4(1.0f).scale(1f, level_squash, 1f)
  level.floor_plane.mvp = game.proj * game.view.translate(-game.pan) * level.floor_plane.model
  level.floor_plane.matrix = level.floor_plane.program.newMatrix(level.floor_plane.mvp, "MVP")

proc init_actors(game: Game) =
  let level = game.get_level()
  for actor in level.actors.mitems:
    if actor.mesh != nil:
      continue
    actor.mesh = Mesh(
      vao       : newVAO(),
      vert_vbo  : newVBO(3, sphere),
      color_vbo : newVBO(4, sphere_enemy_colors),
      elem_vbo  : newElemVBO(sphere_index),
      program   : game.player.mesh.program,
      model     : mat4(1.0f),
    )
    actor.mesh.reset_mesh()
    let x = (actor.origin.x - level.origin.x).float
    let y = actor.origin.y.float
    let z = (actor.origin.z - level.origin.z).float

    actor.mesh.pos    = vec3f(x, y, z)
    actor.mesh.mvp    = game.proj * game.view.translate(-game.pan) * actor.mesh.model
    actor.mesh.matrix = game.player.mesh.program.newMatrix(actor.mesh.mvp, "MVP")

proc set_level(game: Game) =
  let f = game.following
  with game:
    following = false
    goal = false
    hourglass = 0
    reset_player()
    init_floor_plane()
    init_actors()
    reset_player()
    follow_player()
    pan = game.pan_target
    reset_view()
    following = f

proc init(game: var Game) =
  with game:
    init_player()
    level = start_level
    set_level()
    init_floor_plane()
    init_actors()

proc pan_stop =
  game.pan_acc = vec3f(0f,0f,0f)

proc pan_up(press: bool) =
  if press: game.pan_acc.xz = vec2f(-0.125f, -0.125)
  else: pan_stop()
proc pan_down(press: bool) =
  if press: game.pan_acc.xz = vec2f(+0.125, +0.125)
  else: pan_stop()
proc pan_left(press: bool) =
  if press: game.pan_acc.xz = vec2f(-0.125, +0.125)
  else: pan_stop()
proc pan_right(press: bool) =
  if press: game.pan_acc.xz = vec2f(+0.125, -0.125)
  else: pan_stop()
proc pan_in(press: bool) =
  if press: game.pan_acc.y = +0.125
  else: pan_stop()
proc pan_out(press: bool) =
  if press: game.pan_acc.y = -0.125
  else: pan_stop()
proc step_frame(press: bool) =
  if press: game.frame_step = true
proc prev_level(press: bool) =
  if press:
    dec game.level
    game.set_level()
proc next_level(press: bool) =
  if press:
    inc game.level
    game.set_level()
proc follow(press: bool) =
  if press:
    game.following = not game.following
  if not game.following:
    game.pan_target = game.pan
    game.pan_vel *= 0
proc do_goal(press: bool) =
  if press: game.goal = not game.goal
proc toggle_wireframe(press: bool) =
  if press: game.wireframe = not game.wireframe
proc pause(press: bool) =
  if press: game.window.toggle_pause()
proc do_quit(press: bool) =
  game.window.setWindowShouldClose(true)

const keymap = {
  GLFWKey.R            : do_reset_player   ,
  GLFWKey.Up           : pan_up            ,
  GLFWKey.Down         : pan_down          ,
  GLFWKey.Left         : pan_left          ,
  GLFWKey.Right        : pan_right         ,
  GLFWKey.PageUp       : pan_in            ,
  GLFWKey.PageDown     : pan_out           ,
  GLFWKey.S            : step_frame        ,
  GLFWKey.LeftBracket  : prev_level        ,
  GLFWKey.RightBracket : next_level        ,
  GLFWKey.F            : follow            ,
  GLFWKey.G            : do_goal           ,
  GLFWKey.X            : respawn           ,
  GLFWKey.W            : toggle_wireframe  ,
  GLFWKey.P            : pause             ,
  GLFWKey.Q            : do_quit           ,
  GLFWKey.L            : toggle_mouse_lock ,
}.toTable

proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  if keymap.hasKey key:
    game.window = window
    keymap[key](action != GLFWRelease)

proc rotate_mouse(mouse: Vec3f): Vec3f =
  const th = radians(45f)
  const rot_matrix = mat2f(vec2f(cos(th), sin(th)), vec2f(-sin(th), cos(th)))
  let m = rot_matrix * vec2f(mouse.x, mouse.y)
  result = vec3f(m.x, m.y, mouse.z)

proc mouseProc(window: GLFWWindow, xpos, ypos: cdouble): void {.cdecl.} =
  if not game.mouse_lock:
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

  #var dir = vec3f(0,0,1)
  #var axis = game.player.mesh.normal.cross(dir).normalize()
  #let angle = mouse.z
  #game.player.mesh.rot = normalize(quatf(axis, angle) * game.player.mesh.rot)

  #game.fov -= mouse.z
  #game.update_camera()
  #game.update_fov()

proc display_size(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)

proc setup_glfw(): GLFWWindow =
  doAssert glfwInit()

  glfwWindowHint(GLFWContextVersionMajor, 3)
  glfwWindowHint(GLFWContextVersionMinor, 3)
  glfwWindowHint(GLFWOpenglForwardCompat, GLFW_TRUE)
  glfwWindowHint(GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE)
  glfwWindowHint(GLFWResizable, GLFW_FALSE)
  glfwWindowHint(GLFWTransparentFramebuffer, GLFW_FALSE);

  #(width, height) = display_size()
  let w = glfwCreateWindow(width, height, "NimGL", nil, nil)
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

var ig_context: ptr ImGuiContext
var small_font: ptr ImFont
var large_font: ptr ImFont
proc setup_imgui(w: GLFWWindow) =
  ig_context = igCreateContext()
  #var io = igGetIO()
  #io.configFlags = NoMouseCursorChange
  doAssert igGlfwInitForOpenGL(w, true)
  doAssert igOpenGL3Init()
  igStyleColorsDark()
  small_font = ig_context.io.fonts.addFontFromFileTTF("fonts/TerminusTTF.ttf", 14)
  large_font = ig_context.io.fonts.addFontFromFileTTF("fonts/TerminusTTF.ttf", 36)
  #igPushStyleColor ImGuiCol.Text, ImVec4(x:1f, y:0f, z:1f, w:1f)
  igSetNextWindowPos(ImVec2(x:5, y:5))

proc str(f: float): string =
  return f.formatFloat(ffDecimal, 3)

proc str(v: Vec3f): string =
  return "x=" & v.x.str & ", y=" & v.y.str & ", z=" & v.z.str
proc str(v: Vec4f): string =
  return "x=" & v.x.str & ", y=" & v.y.str & ", z=" & v.z.str & ", w=" & v.w.str

proc draw_clock(game: Game) =
  let level = game.get_level()
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 28, y: 0))
  igSetNextWindowSize(ImVec2(x:56, y:48))
  igPushFont( large_font )
  igBegin("CLOCK", nil, ImGuiWindowFlags(171))
  var clk = $(level.clock / 100).int
  if clk.len < 2: clk = "0" & clk
  igText clk
  igEnd()
  igPopFont()

proc draw_goal =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 150, y:mid.y))
  igSetNextWindowSize(ImVec2(x:300f, y:48))
  igPushFont( large_font )
  igBegin("GOAL", nil, ImGuiWindowFlags.NoDecoration)
  igText("Level complete!")
  igPopFont()
  igEnd()

proc draw_imgui =
  igSetNextWindowSize(ImVec2(x:300f, y:400f))
  igPushFont( small_font )

  igBegin("Player vectors")

  #igText("Player vectors")
  #var lateral = player.pos.xz.length()
  #igSliderFloat "lateral_d", lateral.addr     , -sky, sky
  igSliderFloat3 "respawn" , game.respawn_pos.arr  , -sky, sky
  igSliderFloat3 "pos"     , game.player.mesh.pos.arr   , -sky, sky
  igSliderFloat3 "vel"     , game.player.mesh.vel.arr   , -sky, sky
  igSliderFloat3 "acc"     , game.player.mesh.acc.arr   , -sky, sky
  igSliderFloat4 "rot"     , game.player.mesh.rot.arr   , -sky, sky
  #igSliderFloat3 "normal" , game.player.mesh.normal.arr, -1.0, 1.0

  let level = game.get_level()
  let coord = game.player.mesh.pos.rotate_coord
  var cur_mask = ($level.mask_at(coord.x, coord.z)).cstring
  igInputText("cur_mask", curmask, 2)

  var sl = level.slope(coord.x, coord.z) * 0.5f
  igSpacing()
  igSeparator()
  igSpacing()
  igSliderFloat3 "slope"     , sl.arr         , -sky, sky
  igSliderFloat3 "pan_target", game.pan_target.arr , -sky, sky
  igSliderFloat3 "pan"       , game.pan.arr        , -sky, sky
  igSliderFloat3 "pan_vel"   , game.pan_vel.arr    , -sky, sky
  igSliderFloat3 "pan_acc"   , game.pan_acc.arr    , -sky, sky
  igSliderFloat  "fov"       , game.fov.addr       ,   0f, 360f

  igCheckBox     "following"    , game.following.addr
  igCheckBox     "wireframe"    , game.wireframe.addr
  igSliderInt    "current_level", game.level.addr, 1.int32, n_levels.int32 - 1

  #igText("average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
  igEnd()

  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("actor 0")
  if level.actors.len > 0:
    var actor0 = level.actors[0].mesh
    igSliderFloat3 "pos"     , actor0.pos.arr   , -sky, sky
  igEnd()

  #igSetNextWindowPos(ImVec2(x:5, y:500))
  igBegin("camera")
  igSliderFloat3 "pos"   , game.camera_pos.arr   , -sky, sky
  igSliderFloat3 "target", game.camera_target.arr, -sky, sky
  igSliderFloat3 "up"    , game.camera_up.arr    , -sky, sky
  game.view = lookAt( game.camera_pos, game.camera_target, game.camera_up )
  igEnd()

  igPopFont()

proc imgui_frame =
  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  draw_imgui()

  if game.goal:
    draw_goal()
  else:
    game.draw_clock()

  igRender()
  igOpenGL3RenderDrawData(igGetDrawData())

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()

var t  = 0.0f
var dt = 0.0f
var time = 0.0f
var event_time = 0.0f

proc main =
  game = newGame()
  let w = setup_glfw()

  setup_opengl()
  setup_imgui(w)

  game.init()

  proc toString[T: float](f: T, prec: int = 8): string =
    result = f.formatFloat(ffDecimal, prec)

  proc physics(game: var Game, mesh: var Mesh) {.inline.} =
    const mass = player_radius
    const gravity = -49f
    const max_vel = vec3f( 15f, -gravity * 0.5f, 15f )
    let level = game.get_level()
    level.clock += 1
    level.clock = level.clock mod 3600
    let coord = mesh.pos.rotate_coord
    let x = coord.x
    let z = coord.z
    let bh = mesh.pos.y
    let fh = level.point_height(x, z)
    let cur_mask = level.mask_at(x,z)
    #stdout.write "\27[K"

    game.goal = game.goal or cur_mask == GG
    game.dead = mesh.pos.y < 10f or (mesh.acc.xz.length == 0f and mesh.vel.y <= -max_vel.y)

    let ramp = level.slope(x,z) * level_squash * level_squash
    let thx = arctan(ramp.x)
    let thz = arctan(ramp.z)
    let cosx = cos(thx)
    let cosz = cos(thz)
    let sinx = sin(thx)
    let sinz = sin(thz)
    var ramp_a = vec3f( -ramp.x, sinx + sinz, -ramp.z ) * gravity
    var icy = level.around(IC, x,z)
    var traction: float
    if bh - fh > 0.25:
      traction = 0f
    else:
      traction = 1f

    let flat = ramp.length == 0
    let nonzero = level.point_height(x.floor, z.floor) > 0f
    if flat and nonzero and cur_mask == XX and not icy:
      game.respawn_pos = vec3f(mesh.pos.x.floor, mesh.pos.y, mesh.pos.z.floor)

    var m = vec3f(0,0,0)
    if not game.paused and not game.goal and not icy:
      m = rotate_mouse(mouse)

    mesh.acc *= 0
    mesh.acc += mass * vec3f(m.x, 0, -m.y) * traction  # mouse motion
    mesh.acc += vec3f(0, (1f-traction) * gravity, 0)   # free fall
    mesh.acc += ramp_a

    let vel = mesh.vel.length()

    mesh.vel.x = clamp(mesh.vel.x + dt * mesh.acc.x, -max_vel.x, max_vel.x)
    mesh.vel.y = clamp(mesh.vel.y + dt * mesh.acc.y, -max_vel.y * 1.5f, max_vel.y)
    mesh.vel.z = clamp(mesh.vel.z + dt * mesh.acc.z, -max_vel.z, max_vel.z)
    if icy:
      if vel > 0f:
        mesh.vel = mesh.vel.normalize() * vel

    mesh.pos += mesh.vel * dt
    mesh.pos.y = clamp(mesh.pos.y, fh, sky)

    # rotation animation
    if (mesh.vel * vec3f(1,0,1)).length > 0:
      var dir = -mesh.vel.normalize()
      var axis = mesh.normal.cross(dir).normalize()
      let angle = mesh.vel.xz.length * dt / 0.5f / Pi / player_radius
      mesh.rot = normalize(quatf(axis, angle) * mesh.rot)

    const brake = 0.986
    if not icy:
      mesh.vel  *= brake

    mouse *= 0

    mesh.model = mat4(1.0f)
      .translate(vec3f(0, player_radius,0))
      .translate(mesh.pos * vec3f(1,level_squash,1)) * mesh.rot.mat4f

    if level.around(TU,x,z):
      mesh.vel.y = clamp(mesh.vel.y, -max_vel.y, max_vel.y)

    if game.dead:
      respawn(true)

    if game.goal:
      mesh.vel *= 0.97f
      if event_time == 0:
        event_time = time
      if time - event_time > 3.0f:
        game.goal = false
        event_time = 0
        next_level(true)

  proc render(mesh: var Mesh, kind: GLEnum = GL_TRIANGLES) {.inline.} =
    mesh.mvp = game.proj * game.view.translate(-game.pan) * mesh.model
    mesh.matrix.update mesh.mvp
    mesh.program.use()
    mesh.vert_vbo.apply 0
    mesh.color_vbo.apply 1
    if mesh.elem_vbo.n_verts > 0:
      mesh.elem_vbo.draw_elem kind
    else:
      mesh.vert_vbo.draw kind
    glDisableVertexAttribArray 0
    glDisableVertexAttribArray 1

  proc camera_physics(game: Game) {.inline.} =
    game.pan_target += game.pan_acc
    game.pan_vel = (game.pan_vel + game.pan_acc).clamp(-0.125, 0.125)
    game.pan += game.pan_vel

    const camera_maxvel = 1f/20f
    let pan_delta = game.pan_target - game.pan
    if pan_delta.length > 0f:
      if pan_delta.length < camera_maxvel:
        game.pan = game.pan_target
        game.pan_vel *= 0
      else:
        game.pan_vel = pan_delta * dt
        game.pan_vel = clamp(game.pan_vel, -camera_maxvel, +camera_maxvel)

  # main loop
  while not w.windowShouldClose():
    var floor_plane = game.get_level().floor_plane
    var actors = game.get_level().actors
    time = glfwGetTime()
    dt = time - t
    t = time

    if game.paused and game.frame_step:
      game.physics(game.player.mesh)
      game.frame_step = false
    elif not game.paused:
      game.physics(game.player.mesh)

    if not game.paused:
      if game.following:
        game.follow_player()

      game.camera_physics()

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
    game.player.mesh.render

    for a in actors.low..actors.high:
      var mesh = actors[a].mesh

      mesh.model = mat4(1.0f)
        .translate(vec3f(0, player_radius, 0))
        .translate(mesh.pos * vec3f(1,level_squash,1)) * mesh.rot.mat4f

      glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
      mesh.render        GL_TRIANGLE_STRIP

    imgui_frame()

    w.swapBuffers()
    glfwPollEvents()

  w.cleanup()

main()

import os
import std/tables
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

var mouse: Vec3f
var paused = false
var mouse_lock = true
var following = true
var frame_step = false
var goal = false
var dead = false
var wireframe = false

var view: Mat4f
var respawn_pos: Vec3f
var pan_vel: Vec3f
var pan_acc: Vec3f
var pan: Vec3f
var pan_target: Vec3f
var player: Mesh
var actors: seq[Mesh]
var game_window: GLFWWindow
var fov: float32 = 45f
var zoom: float32 = sky * 0.25
const level_squash = 0.5f
const start_level = 1

proc update_camera =
  let level = get_current_level()
  let xlat = vec3f( level.origin.z.float, 0, level.origin.z.float )
  view = lookAt(
    vec3f( zoom, zoom * 0.5, zoom ), # camera pos
    xlat,
    vec3f( 0f,  1.0f,  0f ),        # up
  )

proc reset_view =
  update_camera()
  pan_vel = vec3f(0,0,0)


const field_width = 10f
let aspect: float32 = width / height
var proj: Mat4f
proc update_fov =
  let r: float32 = radians(fov)
  proj = perspective(r, aspect, 0.125f, 150.0f)
  #proj = ortho(aspect * -field_width, aspect * field_width, -field_width, field_width, 0f, sky) # In world coordinates
update_fov()
reset_view()

proc reset_mesh(mesh: Mesh) =
  mesh.pos = vec3f(0f, 0f, 0f)
  mesh.vel = vec3f(0,0,0)
  mesh.acc = vec3f(0,0,0)
  mesh.rot = quatf(vec3f(0,-1,0),0).normalize
  mesh.normal = vec3f(0,-1,0)
  #mesh.rvel = vec3f(0,0,0)
  #mesh.racc = vec3f(0,0,0)

proc reset_player(press: bool) =
  if press:
    let player_top = get_current_level().origin.y.float
    player.reset_mesh()
    player.pos.y = player_top

proc respawn(press: bool) =
  if press:
    reset_player(true)
    player.pos = respawn_pos
    reset_view()

proc rotate_coord(v: Vec3f): Vec3f =
  let v4 = mat4f(1f).translate(v).rotateY(radians(45f))[3]
  result = vec3f(v4.x, v4.y, v4.z)

proc follow_player =
  let level = get_current_level()
  let coord = player.pos.rotate_coord
  let target = player.pos# * 0.5f
  #let target_xz = (target.x + target.z)# / 2f
  #pan_target.x = target_xz
  #pan_target.z = target_xz
  #pan_target.y = level.average_height(coord.x, coord.z) - 5f
  #pan_target.x = target_xz
  #pan_target.z = target_xz

  pan_target = vec3f( coord.x, 0, coord.z )
  pan_target.y = level.average_height(coord.x, coord.z) - 5f
  if goal:
    return
  #pan_target.y -= 5f

proc display_size(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)

proc middle(): Vec2f = vec2f(width.float * 0.5f, height.float * 0.5f)


proc update_mouse_lock =
  if not mouse_lock:
    game_window.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorNormal
  else:
    let mid = middle()
    game_window.setCursorPos mid.x, mid.y
    mouse *= 0
    game_window.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorDisabled

proc toggle_mouse_lock(press: bool) =
  if not press:
    return
  mouse_lock = not mouse_lock
  update_mouse_lock()

proc toggle_pause(w: GLFWWindow) =
  paused = not paused
  if paused:
    mouse_lock = false
    update_mouse_lock()

proc init_floor_plane =
  let level = get_current_level()
  if level.floor_plane != nil:
    return
  level.floor_plane = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, level.floor_verts),
    color_vbo: newVBO(4, level.floor_colors),
    elem_vbo: newElemVBO(level.floor_index),
    program: player.program,
  )
  level.floor_plane.model = mat4(1.0f).scale(1f, level_squash, 1f)
  level.floor_plane.mvp = proj * view.translate(-pan) * level.floor_plane.model
  level.floor_plane.matrix = level.floor_plane.program.newMatrix(level.floor_plane.mvp, "MVP")

proc init_actors =
  let level = get_current_level()
  for actor in level.actors.mitems:
    if actor.mesh != nil:
      continue
    actor.mesh = Mesh(
      vao       : newVAO(),
      vert_vbo  : newVBO(3, sphere),
      color_vbo : newVBO(4, sphere_enemy_colors),
      elem_vbo  : newElemVBO(sphere_index),
      program   : player.program,
      model     : mat4(1.0f),
    )
    actor.mesh.reset_mesh()
    let x = (actor.origin.x - level.origin.x).float
    let y = actor.origin.y.float
    let z = (actor.origin.z - level.origin.z).float

    actor.mesh.pos    = vec3f(x, y, z)
    actor.mesh.mvp    = proj * view.translate(-pan) * actor.mesh.model
    actor.mesh.matrix = player.program.newMatrix(actor.mesh.mvp, "MVP")


proc set_level =
  let f = following
  following = false
  goal = false
  reset_player(true)
  load_level current_level
  init_floor_plane()
  init_actors()
  reset_player(true)
  follow_player()
  #pan_target = player.pos
  pan = pan_target
  reset_view()
  following = f

proc pan_stop =
  pan_acc = vec3f(0f,0f,0f)

proc pan_up(press: bool) =
  if press: pan_acc.xz = vec2f(-0.125f, -0.125)
  else: pan_stop()
proc pan_down(press: bool) =
  if press: pan_acc.xz = vec2f(+0.125, +0.125)
  else: pan_stop()
proc pan_left(press: bool) =
  if press: pan_acc.xz = vec2f(-0.125, +0.125)
  else: pan_stop()
proc pan_right(press: bool) =
  if press: pan_acc.xz = vec2f(+0.125, -0.125)
  else: pan_stop()
proc pan_in(press: bool) =
  if press: pan_acc.y = +0.125
  else: pan_stop()
proc pan_out(press: bool) =
  if press: pan_acc.y = -0.125
  else: pan_stop()
proc step_frame(press: bool) =
  frame_step = true
proc prev_level(press: bool) =
  if press:
    dec current_level
    set_level()
proc next_level(press: bool) =
  if press:
    inc current_level
    set_level()
proc follow(press: bool) =
  if press:
    following = not following
  if not following:
    pan_target = pan
    pan_vel *= 0
proc do_goal(press: bool) =
  if press: goal = not goal
proc toggle_wireframe(press: bool) =
  if press: wireframe = not wireframe
proc pause(press: bool) =
  if press: game_window.toggle_pause()
proc do_quit(press: bool) =
  game_window.setWindowShouldClose(true)

const keymap = {
  GLFWKey.R            : reset_player      ,
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
    game_window = window
    keymap[key](action != GLFWRelease)

proc rotate_mouse(mouse: Vec3f): Vec3f =
  const th = radians(45f)
  const rot_matrix = mat2f(vec2f(cos(th), sin(th)), vec2f(-sin(th), cos(th)))
  let m = rot_matrix * vec2f(mouse.x, mouse.y)
  result = vec3f(m.x, m.y, mouse.z)

proc mouseProc(window: GLFWWindow, xpos, ypos: cdouble): void {.cdecl.} =
  if not mouse_lock:
    return
  let mid = middle()
  if not paused:
    window.setCursorPos mid.x, mid.y
  mouse.x = -(mid.x - xpos)
  mouse.y =  (mid.y - ypos)
  #echo mouse.x, "\r" #, ",", mouse.y

proc scrollProc(window: GLFWWindow, xoffset, yoffset: cdouble): void {.cdecl.} =
  const wheel_ratio = 1.0 / 41.0
  mouse.z = yoffset * wheel_ratio

  #var dir = vec3f(0,0,1)
  #var axis = player.normal.cross(dir).normalize()
  #let angle = mouse.z
  #player.rot = normalize(quatf(axis, angle) * player.rot)

  #fov -= mouse.z
  #update_camera()
  #update_fov()

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
  igSliderFloat3 "respawn" , respawn_pos.arr  , -sky, sky
  igSliderFloat3 "pos"     , player.pos.arr   , -sky, sky
  igSliderFloat3 "vel"     , player.vel.arr   , -sky, sky
  igSliderFloat3 "acc"     , player.acc.arr   , -sky, sky
  igSliderFloat4 "rot"     , player.rot.arr   , -sky, sky
  #igSliderFloat3 "normal" , player.normal.arr, -1.0, 1.0

  let level = get_current_level()
  let coord = player.pos.rotate_coord
  var cur_mask = ($level.mask_at(coord.x, coord.z)).cstring
  igInputText("cur_mask", curmask, 2)

  var sl = level.slope(coord.x, coord.z) * 0.5f
  igSpacing()
  igSeparator()
  igSpacing()
  igSliderFloat3 "slope"     , sl.arr         , -sky, sky
  igSliderFloat3 "pan_target", pan_target.arr , -sky, sky
  igSliderFloat3 "pan"       , pan.arr        , -sky, sky
  igSliderFloat3 "pan_vel"   , pan_vel.arr    , -sky, sky
  igSliderFloat3 "pan_acc"   , pan_acc.arr    , -sky, sky
  igSliderFloat  "fov"       , fov.addr       ,   0f, 360f

  igCheckBox     "following"    , following.addr
  igCheckBox     "wireframe"    , wireframe.addr
  igSliderInt    "current_level", current_level.addr, 1.int32, n_levels.int32 - 1

  #igText("average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
  igPopFont()
  igEnd()

  igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("actor 0")
  igPushFont( small_font )
  if level.actors.len > 0:
    var actor0 = level.actors[0].mesh
    igSliderFloat3 "pos"     , actor0.pos.arr   , -sky, sky
  igPopFont()
  igEnd()

proc imgui_frame =
  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  draw_imgui()

  if goal:
    draw_goal()

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
  let w = setup_glfw()

  ## chapter 1
  setup_opengl()
  setup_imgui(w)

  ## chapter 2
  player = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, sphere),
    color_vbo: newVBO(4, sphere_colors),
    elem_vbo: newElemVBO(sphere_index),
    program: newProgram(frags, verts, geoms),
  )
  reset_player(true)

  player.model  = mat4(1.0f)
  player.mvp    = proj * view.translate(-pan) * player.model
  player.matrix = player.program.newMatrix(player.mvp, "MVP")

  current_level = start_level
  set_level()
  init_floor_plane()
  init_actors()

  proc toString[T: float](f: T, prec: int = 8): string =
    result = f.formatFloat(ffDecimal, prec)

  proc physics(player: var Mesh) =
    const mass = player_radius
    const gravity = -49f
    const max_vel = vec3f( 15f, -gravity * 0.5f, 15f )
    let level = get_current_level()
    level.clock += 1
    level.clock = level.clock mod 3600
    let coord = player.pos.rotate_coord
    let x = coord.x
    let z = coord.z
    let bh = player.pos.y
    let fh = level.point_height(x, z)
    let cur_mask = level.mask_at(x,z)
    #stdout.write "\27[K"

    goal = goal or cur_mask == GG
    dead = player.pos.y < 10f or player.vel.y <= -max_vel.y

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
      respawn_pos = vec3f(player.pos.x.floor, player.pos.y, player.pos.z.floor)

    var m = vec3f(0,0,0)
    if not paused and not goal and not icy:
      m = rotate_mouse(mouse)

    player.acc *= 0
    player.acc += mass * vec3f(m.x, 0, -m.y) * traction  # mouse motion
    player.acc += vec3f(0, (1f-traction) * gravity, 0)   # free fall
    player.acc += ramp_a

    let vel = player.vel.length()

    player.vel.x = clamp(player.vel.x + dt * player.acc.x, -max_vel.x, max_vel.x)
    player.vel.y = clamp(player.vel.y + dt * player.acc.y, -max_vel.y * 1.5f, max_vel.y)
    player.vel.z = clamp(player.vel.z + dt * player.acc.z, -max_vel.z, max_vel.z)
    if icy:
      if vel > 0f:
        player.vel = player.vel.normalize() * vel

    player.pos += player.vel * dt
    player.pos.y = clamp(player.pos.y, fh, sky)

    # rotation animation
    if (player.vel * vec3f(1,0,1)).length > 0:
      var dir = -player.vel.normalize()
      var axis = player.normal.cross(dir).normalize()
      let angle = player.vel.xz.length * dt / 0.5f / Pi / player_radius
      player.rot = normalize(quatf(axis, angle) * player.rot)

    const brake = 0.986
    if not icy:
      player.vel  *= brake

    mouse *= 0

    player.model = mat4(1.0f)
      .translate(vec3f(0, player_radius,0))
      .translate(player.pos * vec3f(1,level_squash,1)) * player.rot.mat4f

    if level.around(TU,x,z):
      player.vel.y = clamp(player.vel.y, -max_vel.y, max_vel.y)

    if dead:
      respawn(true)

    if goal:
      player.vel *= 0.97f
      if event_time == 0:
        event_time = time
      if time - event_time > 3.0f:
        goal = false
        event_time = 0
        next_level(true)

  proc render(mesh: var Mesh, kind: GLEnum = GL_TRIANGLES) {.inline.} =
    mesh.mvp = proj * view.translate(-pan) * mesh.model
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

  proc camera_physics {.inline.} =
    pan_target += pan_acc
    pan_vel = (pan_vel + pan_acc).clamp(-0.125, 0.125)
    pan += pan_vel

    const camera_maxvel = 1f/24f
    let pan_delta = pan_target - pan
    if pan_delta.length > 0f:
      if pan_delta.length < camera_maxvel:
        pan = pan_target
        pan_vel *= 0
      else:
        pan_vel = pan_delta * dt
        pan_vel = clamp(pan_vel, -camera_maxvel, +camera_maxvel)

  # main loop
  while not w.windowShouldClose():
    var floor_plane = get_current_level().floor_plane
    var actors = get_current_level().actors
    time = glfwGetTime()
    dt = time - t
    t = time

    if paused and frame_step:
      player.physics()
      frame_step = false
    elif not paused:
      player.physics()

    if not paused:
      if following:
        follow_player()

      camera_physics()

    glClear            GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    if not wireframe:
      glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
      glEnable           GL_POLYGON_OFFSET_FILL
      glPolygonOffset 1f, 1f
      floor_plane.render GL_TRIANGLE_STRIP
      glDisable          GL_POLYGON_OFFSET_FILL

    glPolygonMode      GL_FRONT_AND_BACK, GL_LINE
    floor_plane.render GL_TRIANGLE_STRIP

    glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
    player.render

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

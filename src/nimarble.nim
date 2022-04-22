import os
import strutils
import nimgl/[glfw,opengl]
import nimgl/imgui
import nimgl/imgui/[impl_opengl, impl_glfw]
import glm

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

type
  VAO = object
    id: uint32
  VBO[T] = object
    id: uint32
    dimensions: cint
    n_verts: cint
    data: seq[T]
  Shader = object
    id: uint32
    code: cstring
  Program = object
    id: uint32
    vertex: Shader
    fragment: Shader
  Matrix = object
    id: GLint
    matrix*: Mat4f

type Mesh = ref object
  pos, vel, acc: Vec3f
  rot: Quatf
  vao: VAO
  vert_vbo, color_vbo: VBO[cfloat]
  elem_vbo: VBO[cushort]
  mvp: Mat4f
  model: Mat4f
  matrix: Matrix
  program: Program


proc update(matrix: Matrix, value: var Mat4f) =
  glUniformMatrix4fv matrix.id, 1, false, value.caddr

proc newMatrix(program: Program, matrix: var Mat4f, name: string): Matrix =
  result.matrix = matrix
  result.id = glGetUniformLocation(program.id, name)
  #result.update matrix

proc newVAO(): VAO =
  glGenVertexArrays(1, result.id.addr)
  glBindVertexArray(result.id)

proc newVBO[T](n: cint, data: var seq[T]): VBO[T] =
  result.data = data
  result.dimensions = n
  result.n_verts = data.len.cint div n
  glGenBuffers 1, result.id.addr
  glBindBuffer GL_ARRAY_BUFFER, result.id
  glBufferData GL_ARRAY_BUFFER, cint(T.sizeof * result.data.len), result.data[0].addr, GL_STATIC_DRAW

proc newElemVBO[T](data: var seq[T]): VBO[T] =
  result.data = data
  result.dimensions = 1
  result.n_verts = data.len.cint
  glGenBuffers 1, result.id.addr
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, result.id
  glBufferData GL_ELEMENT_ARRAY_BUFFER, cint(T.sizeof * result.data.len), result.data[0].addr, GL_STATIC_DRAW

proc check(shader: Shader) =
  var status: int32
  shader.id.glGetShaderiv GL_COMPILE_STATUS, status.addr
  if status != GL_TRUE.ord:
    var
      log_length: int32
      message = newSeq[char](1024)
    shader.id.glGetShaderInfoLog 1024, log_length.addr, message[0].addr
    for m in message:
      stdout.write(m)
    stdout.write("\n")

proc check(program: Program) =
  var
    log_length: int32
    message = newSeq[char](1024)
    pLinked: int32
  program.id.glGetProgramiv GL_LINK_STATUS, pLinked.addr
  if pLinked != GL_TRUE.ord:
    program.id.glGetProgramInfoLog 1024, log_length.addr, message[0].addr
    for m in message:
      stdout.write(m)
    stdout.write("\n")

proc newShader(kind: GLEnum, code: var cstring): Shader =
  result.id = glCreateShader kind
  result.id.glShaderSource 1'i32, code.addr, nil
  result.id.glCompileShader
  result.check

proc `=destroy`(o: var VAO) = glDeleteVertexArrays 1, o.id.addr
proc `=destroy`[T](o: var VBO[T]) = glDeleteBuffers 1, o.id.addr
proc `=destroy`(shader: var Shader) = shader.id.glDeleteShader
proc `=destroy`(program: var Program) = program.id.glDeleteProgram

proc newProgram(frag_code, vert_code, geom_code: var cstring): Program =
  var fragment, vertex, geometry: Shader
  fragment = newShader(GL_FRAGMENT_SHADER, frag_code)
  vertex = newShader(GL_VERTEX_SHADER, vert_code)
  if geom_code.len > 2:
    geometry = newShader(GL_GEOMETRY_SHADER, geom_code)

  result.id = glCreateProgram()
  result.id.glAttachShader fragment.id
  result.id.glAttachShader vertex.id
  if geometry.id != 0:
    result.id.glAttachShader geometry.id
  result.id.glLinkProgram
  result.check
  result.id.glDetachShader fragment.id
  result.id.glDetachShader vertex.id
  if geometry.id != 0:
    result.id.glDetachShader geometry.id

var width, height: int32
width = 1600
height = 1200

var view: Mat4f
var pan_vel: Vec3f
var pan: Vec3f
var player: Mesh
const level_squash = 0.5f
let player_top = oy * level_squash * 2f

proc reset_view =
  let distance = oy
  let xlat = vec3f( oz*1.5, 0, oz*1.5 )
  view = lookAt(
    vec3f( 0f,  distance,  distance ), # camera pos
    vec3f( 0f,  0f,   0f ), # target
    vec3f( 0f,   1f,   0f ), # up
  ).rotateY(radians(-45f)).translate( xlat )
  pan = vec3f(0,0,0)

proc reset_player =
  player.pos = vec3f(0f, player_top, 0f)
  player.vel = vec3f(0,0,0)
  player.acc = vec3f(0,0,0)
  player.rot = quatf(vec3f(0,0,0), 0)
  #player.rvel = vec3f(0,0,0)
  #player.racc = vec3f(0,0,0)
  pan_vel = vec3f(0,0,0)

proc rotate_coord(v: Vec3f): Vec3f =
  let v4 = mat4f(1f).scale(0.5f).translate(v).rotateY(radians(45f))[3]
  result = vec3f(v4.x, v4.y, v4.z)

proc follow_player =
  let threshold = 4f

  #echo player.pos
  #let pla = rotate_coord(player.pos) * vec3f(1,0,1)
  let pla = player.pos * vec3f(0.5,0,0.5)
  let offset = vec3f(-5, 0, -5)
  let d = pla - pan - offset
  let delta = d.x + d.z
  #stdout.write ", pla=", pla
  stdout.write ", delta=", delta

  if delta < -threshold:
    pan += vec3f(-0.1f, 0f, -0.1f)
  if delta > threshold:
    pan += vec3f(+0.1f, 0f, +0.1f)

proc display_size(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)

proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  case key
  of GLFWKey.Up:
    if action == GLFWPress:
      pan_vel += vec3f(-0.1f, 0f, -0.1f)
    elif action == GLFWRelease:
      pan_vel = vec3f(0f,0f,0f)
  of GLFWKey.Down:
    if action == GLFWPress:
      pan_vel += vec3f(+0.1f, 0f, +0.1f)
    elif action == GLFWRelease:
      pan_vel = vec3f(0f,0f,0f)
  of GLFWKey.Left:
    if action == GLFWPress:
      pan_vel += vec3f(-0.1f, 0f, +0.1f)
    elif action == GLFWRelease:
      pan_vel = vec3f(0f,0f,0f)
  of GLFWKey.Right:
    if action == GLFWPress:
      pan_vel += vec3f(+0.1f, 0f, -0.1f)
    elif action == GLFWRelease:
      pan_vel = vec3f(0f,0f,0f)
  of GLFWKey.PageUp:
    if action == GLFWPress:
      pan_vel += vec3f(0f, +0.1f, 0f)
    elif action == GLFWRelease:
      pan_vel = vec3f(0f,0f,0f)
  of GLFWKey.PageDown:
    if action == GLFWPress:
      pan_vel += vec3f(0f, -0.1f, 0f)
    elif action == GLFWRelease:
      pan_vel = vec3f(0f,0f,0f)
  of GLFWKey.R:
    reset_player()
    reset_view()
  of GLFWKey.Q,
     GLFWKey.Escape:
    window.setWindowShouldClose(true)
  else: discard
  pan_vel = pan_vel.clamp(-0.1f, 0.1f)

proc middle(): Vec2f = vec2f(width.float * 0.5f, height.float * 0.5f)

proc rotate_mouse(mouse: Vec3f): Vec3f =
  const th = radians(45f)
  const rot_matrix = mat2f(vec2f(cos(th), sin(th)), vec2f(-sin(th), cos(th)))
  let m = rot_matrix * vec2f(mouse.x, mouse.y)
  result = vec3f(m.x, m.y, mouse.z)

var mouse: Vec3f
proc mouseProc(window: GLFWWindow, xpos, ypos: cdouble): void {.cdecl.} =
  let mid = middle()
  window.setCursorPos mid.x, mid.y
  mouse.x = -(mid.x - xpos)
  mouse.y =  (mid.y - ypos)
  #echo mouse.x, "\r" #, ",", mouse.y

proc scrollProc(window: GLFWWindow, xoffset, yoffset: cdouble): void {.cdecl.} =
  #const wheel_ratio = 1.0 / 41.0
  mouse.z = yoffset #* wheel_ratio

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

  glClear(GL_COLOR_BUFFER_BIT)
  glEnable GL_DEPTH_TEST # Enable depth test
  glDepthFunc GL_LESS    # Accept fragment if it closer to the camera than the former one

  glEnable GL_BLEND
  glBlendFunc GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA

proc apply(vbo: VBO, n: GLuint) {.inline.} =
  glEnableVertexAttribArray n
  glBindBuffer GL_ARRAY_BUFFER, vbo.id
  glVertexAttribPointer n, vbo.dimensions, EGL_FLOAT, false, 0, nil

proc draw(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glDrawArrays kind, 0, vbo.n_verts

proc draw_elem(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, vbo.id
  glDrawElements kind, vbo.n_verts, GL_UNSIGNED_SHORT, nil

var ig_context: ptr ImGuiContext
proc setup_imgui(w: GLFWWindow) =
  ig_context = igCreateContext()
  #var io = igGetIO()
  #io.configFlags = NoMouseCursorChange
  doAssert igGlfwInitForOpenGL(w, true)
  doAssert igOpenGL3Init()
  igStyleColorsDark()
  #igPushStyleColor ImGuiCol.Text, ImVec4(x:1f, y:0f, z:1f, w:1f)

proc str(f: float): string =
  return f.formatFloat(ffDecimal, 3)

proc str(v: Vec3f): string =
  return "x=" & v.x.str & ", y=" & v.y.str & ", z=" & v.z.str

var somefloat: float32 = 0.0f
var counter: int32 = 0
proc draw_imgui =
  igSetNextWindowPos(ImVec2(x:5, y:5))
  igSetNextWindowSize(ImVec2(x:300f, y:240f))
  igBegin("Player vectors")

  #igText("Player vectors")
  igSliderFloat3("pos", player.pos.arr, -sky, sky)
  igSliderFloat3("vel", player.vel.arr, -sky, sky)
  igSliderFloat3("acc", player.acc.arr, -sky, sky)

  igSliderFloat4("rot", player.rot.arr, -sky, sky)
  #igSliderFloat3("rvel", player.rvel.arr, -sky, sky)
  #igSliderFloat3("racc", player.racc.arr, -sky, sky)

  var sl = slope(player.pos.rotate_coord.x, player.pos.rotate_coord.z)
  igSpacing()
  igSeparator()
  igSpacing()
  igSliderFloat3("slope", sl.arr, -100f, 100f)
  igSliderFloat3("pan", pan.arr, -100f, 100f)

  #igText("average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
  igEnd()

proc imgui_frame =
  igOpenGL3NewFrame()
  igGlfwNewFrame()
  igNewFrame()

  draw_imgui()

  igRender()
  igOpenGL3RenderDrawData(igGetDrawData())

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()

const field_width = 10f
let aspect: float32 = width / height
#var proj: Mat4f = perspective(radians(30.0f), aspect, 0.1f, 150.0f)
var proj: Mat4f = ortho(aspect * -field_width, aspect * field_width, -field_width, field_width, 0f, sky) # In world coordinates
reset_view()

var t  = 0.0f
var dt = 0.0f
var time = 0.0f

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
  reset_player()

  var floor_plane = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, floor_verts),
    color_vbo: newVBO(4, floor_colors),
    elem_vbo: newElemVBO(floor_index),
    program: player.program,
  )

  player.model  = mat4(1.0f).scale(0.5f)
  player.mvp    = proj * view.translate(-pan) * player.model
  player.matrix = player.program.newMatrix(player.mvp, "MVP")

  floor_plane.model = mat4(1.0f).scale(1f, level_squash, 1f)#.rotateY(radians(-45f))
  floor_plane.mvp = proj * view.translate(-pan) * floor_plane.model
  floor_plane.matrix = floor_plane.program.newMatrix(floor_plane.mvp, "MVP")

  proc toString[T: float](f: T, prec: int = 8): string =
    result = f.formatFloat(ffDecimal, prec)

  proc physics(player: var Mesh) =
    const mass = 1.0f
    const max_vel = 15.0f * vec3f( 1f, 1f, 1f )
    const gravity = -59f
    let coord = rotate_coord(player.pos)
    let x = coord.x
    let z = coord.z
    let bh = player.pos.y / level_squash / 2f
    let fh = point_height(x, z)
    #stdout.write "\27[K"

    var floor = -gravity
    if fh < bh:
      floor = 0f
    else:
      player.vel.y = 0f
    let m = rotate_mouse(mouse)
    let ay = floor + gravity
    player.acc = mass * vec3f(m.x, ay, -m.y) - gravity * slope(x,z) * 0.25
    player.vel = clamp(player.vel + dt * player.acc, -max_vel, max_vel)
    player.pos += player.vel * dt
    player.pos.y = clamp(player.pos.y, fh, sky)

    const max_rvel = vec3f(6f,6f,6f)
    #player.racc.y += mouse.z
    player.rot = player.rot
      .rotate( 0.03 * player.vel.length, player.vel.normalize())

    const friction = 0.986
    player.vel  *= friction
    #player.rvel *= friction
    #player.racc *= friction

    mouse *= 0

    player.model = mat4(1.0f).scale(0.5f).translate(player.pos) * player.rot.mat4f
      #.rotateX(radians(360 * player.rot.x))
      #.rotateZ(radians(360 * player.rot.z))
      #.rotateY(radians(360 * player.rot.y))

  proc render(mesh: var Mesh, kind: GLEnum = GL_TRIANGLES) {.inline.} =
    mesh.mvp = proj * view.translate(-pan) * mesh.model
    mesh.matrix.update mesh.mvp
    glUseProgram mesh.program.id
    mesh.vert_vbo.apply 0
    mesh.color_vbo.apply 1
    if mesh.elem_vbo.n_verts > 0:
      mesh.elem_vbo.draw_elem kind
    else:
      mesh.vert_vbo.draw kind
    glDisableVertexAttribArray 0
    glDisableVertexAttribArray 1

  # main loop
  while not w.windowShouldClose():
    time = glfwGetTime()
    dt = time - t
    t = time

    #follow_player()
    pan += pan_vel


    player.physics()

    glClear            GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    #glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
    #glEnable           GL_POLYGON_OFFSET_FILL
    #glPolygonOffset 1f, 1f
    #floor_plane.render GL_TRIANGLE_STRIP
    #glDisable          GL_POLYGON_OFFSET_FILL

    glPolygonMode      GL_FRONT_AND_BACK, GL_LINE
    floor_plane.render GL_TRIANGLE_STRIP

    glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
    player.render

    imgui_frame()

    w.swapBuffers()
    glfwPollEvents()

  w.cleanup()

main()

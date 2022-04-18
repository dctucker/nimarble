import os
import nimgl/glfw
import nimgl/opengl
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

proc update(matrix: Matrix, value: var Mat4f) =
  glUniformMatrix4fv matrix.id, 1, false, value.caddr

proc newMatrix(program: Program, matrix: var Mat4f, name: string): Matrix =
  result.matrix = matrix
  result.id = glGetUniformLocation(program.id, name)
  result.update matrix

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

proc display_size(): (int32, int32) =
  var monitor = glfwGetPrimaryMonitor()
  var videoMode = monitor.getVideoMode()
  return (videoMode.width, videoMode.height)

proc keyProc(window: GLFWWindow, key: int32, scancode: int32, action: int32, mods: int32): void {.cdecl.} =
  case action
  of GLFWPress:
    case key
    of GLFWKey.Q,
       GLFWKey.Escape:
      window.setWindowShouldClose(true)
    else: discard
  of GLFWRelease:
    discard
  else: discard

proc middle(): Vec2f = vec2f(width.float * 0.5f, height.float * 0.5f)

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

  w.setInputMode GLFW_CURSOR_SPECIAL, GLFW_CURSOR_HIDDEN
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

proc drawElem(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, vbo.id
  glDrawElements kind, vbo.n_verts, GL_UNSIGNED_SHORT, nil

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()

type Mesh = ref object
  pos, vel, acc: Vec3f
  rot, rvel, racc: cfloat
  vao: VAO
  vert_vbo, color_vbo: VBO[cfloat]
  elem_vbo: VBO[cushort]
  mvp: Mat4f
  model: Mat4f
  matrix: Matrix
  program: Program

## chapter 3
let aspect: float32 = width / height
var proj: Mat4f = perspective(radians(45.0f), aspect, 0.1f, 100.0f)
#var proj: Mat4f = ortho(-10.0f, 10.0f, -10.0f, 10.0f, 0.0f, 20.0f) # In world coordinates
var view = lookAt(
  vec3f( 0f,  40f,  29f ), # camera pos
  vec3f( 0f,   0f,   0f ), # target
  vec3f( 0f,   1f,   0f ), # up
).rotateY(radians(-45f))

var t  = 0.0f
var dt = 0.0f
var time = 0.0f

proc main =
  let w = setup_glfw()
  const level_squash = 0.2f
  const player_top = 1f + 50f * level_squash * 2f

  ## chapter 1
  setup_opengl()

  ## chapter 2
  var player = Mesh(
    pos: vec3f(0f, player_top, 0f),
    vel: vec3f(0f, 0f, 0f),
    acc: vec3f(0f, 0f, 0f),
    rot: 0f,
    rvel: 0f,
    racc: 0f,
    vao: newVAO(),
    vert_vbo: newVBO(3, cube),
    color_vbo: newVBO(4, cube_colors),
    elem_vbo: newElemVBO(cube_index),
    program: newProgram(frags, verts, geoms),
  )

  var floor_plane = Mesh(
    vao: newVAO(),
    vert_vbo: newVBO(3, floor_verts),
    color_vbo: newVBO(4, floor_colors),
    elem_vbo: newElemVBO(floor_index),
    program: player.program,
  )

  player.model  = mat4(1.0f).scale(0.5f).translate(player.pos)
  player.mvp    = proj * view * player.model
  player.matrix = player.program.newMatrix(player.mvp, "MVP")

  floor_plane.model = mat4(1.0f).scale(1f, level_squash, 1f)#.rotateY(radians(-45f))
  floor_plane.mvp = proj * view * floor_plane.model
  floor_plane.matrix = floor_plane.program.newMatrix(floor_plane.mvp, "MVP")

  proc rotate_mouse(mouse: Vec3f): Vec3f =
    const th = radians(45f)
    const rot_matrix = mat2f(vec2f(cos(th), sin(th)), vec2f(-sin(th), cos(th)))
    let m = rot_matrix * vec2f(mouse.x, mouse.y)
    result = vec3f(m.x, m.y, mouse.z)

  proc physics(mesh: var Mesh) =
    const mass = 5.0f
    const max_vel = 20.0f * vec3f( 1f, 1f, 1f )
    const gravity = -9.8f
    let coord = mat4f(1f).scale(0.5f).translate(mesh.pos).rotateY(radians(45f))[3]
    let x = coord.x.int
    let z = coord.z.int
    let fh = floor_height(x, z)
    let bh = mesh.pos.y / level_squash / 2f
    #stdout.write "\rx = ", x, ", z = ", z, ", y = ", bh.int, ", h = ", fh.int, "\27[K"
    var floor = 9.8f
    if fh < bh:
      floor = 0f
    else:
      mesh.vel.y = 0f
      mesh.pos.y = fh * level_squash * 2
    let m = rotate_mouse(mouse)
    mesh.acc = mass * vec3f(m.x, floor + gravity, -m.y)
    mesh.vel = clamp(mesh.vel + dt * mesh.acc, -max_vel, max_vel)
    mesh.pos += mesh.vel * dt

    const max_rvel = 6.0f
    mesh.racc += mouse.z
    mesh.rvel  = clamp( mesh.rvel + dt * mesh.racc, -max_rvel, max_rvel )
    mesh.rot  += mesh.rvel * dt

    const friction = 0.986
    mesh.vel  *= friction
    mesh.rvel *= friction
    mesh.racc *= friction

    mouse *= 0

    mesh.model = mat4(1.0f)
      .scale(0.5f)
      .translate(mesh.pos)
      .rotateY(radians(360 * mesh.rot))
    mesh.mvp = proj * view * mesh.model

  proc render(mesh: var Mesh, kind: GLEnum = GL_TRIANGLES) {.inline.} =
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

    player.physics()

    glClear            GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
    glEnable           GL_POLYGON_OFFSET_FILL
    glPolygonOffset 1f, 1f
    floor_plane.render GL_TRIANGLE_STRIP
    glDisable          GL_POLYGON_OFFSET_FILL

    glPolygonMode      GL_FRONT_AND_BACK, GL_LINE
    floor_plane.render GL_TRIANGLE_STRIP

    glPolygonMode      GL_FRONT_AND_BACK, GL_FILL
    player.render

    w.swapBuffers()
    glfwPollEvents()

  w.cleanup()

main()

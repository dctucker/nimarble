import os
import nimgl/glfw
import nimgl/opengl
import glm

import models
import level1
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
  VBO = object
    id: uint32
    dimensions: cint
    n_verts: cint
    data: seq[cfloat]
  Shader = object
    id: uint32
    code: cstring
  Program = object
    id: uint32
    vertex: Shader
    fragment: Shader
  Matrix = object
    id: GLint
    mvp*: Mat4f

proc update(matrix: Matrix, value: var Mat4f) =
  matrix.id.glUniformMatrix4fv 1, false, value.caddr

proc newMatrix(program: Program, mvp: var Mat4f): Matrix =
  result.mvp = mvp
  result.id = glGetUniformLocation(program.id, "MVP")
  result.update mvp

proc newVAO(): VAO =
  glGenVertexArrays(1, result.id.addr)
  glBindVertexArray(result.id)

proc newVBO[T](n: cint, data: var seq[T]): VBO =
  result.data = data
  result.dimensions = n
  result.n_verts = data.len.cint div n
  glGenBuffers 1, result.id.addr
  glBindBuffer GL_ARRAY_BUFFER, result.id
  glBufferData GL_ARRAY_BUFFER, cint(T.sizeof * result.data.len), result.data[0].addr, GL_STATIC_DRAW


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
proc `=destroy`(o: var VBO) = glDeleteBuffers 1, o.id.addr
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

var mouse: Vec3f
proc mouseProc(window: GLFWWindow, xpos, ypos: cdouble): void {.cdecl.} =
  let middle = vec2f(width.float * 0.5f, height.float * 0.5f)
  window.setCursorPos middle.x, middle.y
  mouse.x = -(middle.x - xpos)
  mouse.y =  (middle.y - ypos)
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
  width = 1600
  height = 1200
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


proc len(vbo: VBO): GLint {.inline.} =
  return (vbo.data.len() div 3).int32

proc apply(vbo: VBO, n: GLuint) {.inline.} =
  glEnableVertexAttribArray n
  glBindBuffer GL_ARRAY_BUFFER, vbo.id
  glVertexAttribPointer n, vbo.dimensions, EGL_FLOAT, false, 0, nil

proc draw(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glDrawArrays kind, 0, vbo.n_verts

proc cleanup(w: GLFWWindow) =
  w.destroyWindow
  glfwTerminate()

proc setup_colors(): seq[cfloat] =
  result = newSeq[cfloat](36*3)
  for i in 0..<36:
    let phase = (i.cfloat/36.0f)
    result[3*i+0] = 0.0f * phase
    result[3*i+1] = 1.0f * phase
    result[3*i+2] = 0.5f * (1.0-phase)

type Mesh = ref object
  pos, vel, acc: Vec3f
  rot, rvel, racc: cfloat
  vao: VAO
  vert_vbo, color_vbo: VBO
  mvp: Mat4f
  model: Mat4f
  matrix: Matrix
  program: Program

proc main =
  let w = setup_glfw()

  ## chapter 1
  setup_opengl()

  ## chapter 2
  var color_buf = setup_colors()
  var player = Mesh(
    pos: vec3f(0f, 0f, 0f),
    vel: vec3f(0f, 0f, 0f),
    acc: vec3f(0f, 0f, 0f),
    rot: 0f,
    rvel: 0f,
    racc: 0f,
    vao: newVAO(),
    vert_vbo: newVBO(3, cube),
    color_vbo: newVBO(3, color_buf),
    program: newProgram(frags, verts, geoms),
  )

  ## chapter 3
  let aspect: float32 = width / height
  var proj: Mat4f = perspective(radians(45.0f), aspect, 0.1f, 100.0f)
  #var proj: Mat4f = ortho(-10.0f, 10.0f, -10.0f, 10.0f, 0.0f, 20.0f) # In world coordinates
  var view = lookAt(
    vec3f( 0f,  7f,  49f ), # camera pos
    vec3f( 0f,  0f,  0f ), # target
    vec3f( 0f,  1f,  0f ), # up
  )
  player.model  = mat4(1.0f).translate(player.pos)
  player.mvp    = proj * view * player.model
  player.matrix = player.program.newMatrix(player.mvp)

  var t  = 0.0f
  var dt = 0.0f
  proc physics() =
    let time = glfwGetTime()
    dt = time - t
    t = time

    const mass = 1.0f
    const max_vel = 20.0f * vec3f( 1f, 1f, 1f )
    player.acc = mass * vec3f(mouse.x, mouse.y, 0)
    player.vel = clamp(player.vel + dt * player.acc, -max_vel, max_vel)
    player.pos += player.vel * dt

    const max_rvel = 6.0f
    player.racc += mouse.z
    player.rvel  = clamp( player.rvel + dt * player.racc, -max_rvel, max_rvel )
    player.rot  += player.rvel * dt

    const friction = 0.995
    player.vel  *= friction
    player.rvel *= friction
    player.racc *= friction

    mouse *= 0

    player.model = mat4(1.0f)
      .translate(player.pos)
      .rotateY(radians(360 * player.rot))
    player.mvp = proj * view * player.model
    player.matrix.update player.mvp


  # main loop
  while not w.windowShouldClose():
    physics()

    glClear GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    glUseProgram player.program.id

    player.vert_vbo.apply 0
    player.color_vbo.apply 1
    player.vert_vbo.draw()

    glDisableVertexAttribArray 0
    glDisableVertexAttribArray 1

    w.swapBuffers()
    glfwPollEvents()

  w.cleanup()

main()

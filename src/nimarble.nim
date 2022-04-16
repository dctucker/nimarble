import os
import nimgl/glfw
import nimgl/opengl
import glm

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


proc statusShader(shader: uint32) =
  var status: int32
  glGetShaderiv(shader, GL_COMPILE_STATUS, status.addr);
  if status != GL_TRUE.ord:
    var
      log_length: int32
      message = newSeq[char](1024)
    glGetShaderInfoLog(shader, 1024, log_length.addr, message[0].addr);
    for m in message:
      stdout.write(m)
    stdout.write("\n")

proc statusProgram(program: uint32) =
  var
    log_length: int32
    message = newSeq[char](1024)
    pLinked: int32
  program.glGetProgramiv GL_LINK_STATUS, pLinked.addr
  if pLinked != GL_TRUE.ord:
    program.glGetProgramInfoLog 1024, log_length.addr, message[0].addr
    for m in message:
      stdout.write(m)
    stdout.write("\n")

proc initShader(shader: var Shader, code: var cstring) =
  shader.id.glShaderSource 1'i32, code.addr, nil
  shader.id.glCompileShader
  shader.id.statusShader

proc newFragmentShader(code: var cstring): Shader =
  result.id = glCreateShader GL_FRAGMENT_SHADER
  result.initShader code

proc newVertexShader(code: var cstring): Shader =
  result.id = glCreateShader GL_VERTEX_SHADER
  result.initShader code

proc `=destroy`(o: var VAO) = glDeleteVertexArrays 1, o.id.addr
proc `=destroy`(o: var VBO) = glDeleteBuffers 1, o.id.addr
proc `=destroy`(shader: var Shader) = shader.id.glDeleteShader
proc `=destroy`(program: var Program) = program.id.glDeleteProgram

proc newProgram(frag_code, vert_code: var cstring): Program =
  var fragment = newFragmentShader(frag_code)
  var vertex = newVertexShader(vert_code)

  result.id = glCreateProgram()
  result.id.glAttachShader fragment.id
  result.id.glAttachShader vertex.id
  result.id.glLinkProgram
  result.id.statusProgram
  result.id.glDetachShader fragment.id
  result.id.glDetachShader vertex.id

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

var mouse_x, mouse_y, mouse_z: cdouble
proc mouseProc(window: GLFWWindow, xpos, ypos: cdouble): void {.cdecl.} =
  window.setCursorPos width.float * 0.5f, height.float * 0.5f
  mouse_x =  (xpos / width.cdouble)  - 0.5
  mouse_y = -(ypos / height.cdouble) + 0.5

proc scrollProc(window: GLFWWindow, xoffset, yoffset: cdouble): void {.cdecl.} =
  const wheel_ratio = 1.0 / 41.0
  mouse_z = yoffset * wheel_ratio

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

proc draw(vbo: VBO) {.inline.} =
  glDrawArrays GL_TRIANGLES, 0, vbo.n_verts # Starting from vertex 0; 3 vertices total -> 1 triangle

proc cleanup(w: GLFWWindow) =
  w.destroyWindow
  glfwTerminate()

var cube = @[
  -1.0f, -1.0f, -1.0f, # triangle 1 : begin
  -1.0f, -1.0f, +1.0f,
  -1.0f, +1.0f, +1.0f, # triangle 1 : end
  +1.0f, +1.0f, -1.0f, # triangle 2 : begin
  -1.0f, -1.0f, -1.0f,
  -1.0f, +1.0f, -1.0f, # triangle 2 : end
  +1.0f, -1.0f, +1.0f,
  -1.0f, -1.0f, -1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, +1.0f, -1.0f,
  +1.0f, -1.0f, -1.0f,
  -1.0f, -1.0f, -1.0f,
  -1.0f, -1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  -1.0f, +1.0f, -1.0f,
  +1.0f, -1.0f, +1.0f,
  -1.0f, -1.0f, +1.0f,
  -1.0f, -1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  -1.0f, -1.0f, +1.0f,
  +1.0f, -1.0f, +1.0f,
  +1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, +1.0f, -1.0f,
  +1.0f, -1.0f, -1.0f,
  +1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, +1.0f,
  +1.0f, +1.0f, +1.0f,
  +1.0f, +1.0f, -1.0f,
  -1.0f, +1.0f, -1.0f,
  +1.0f, +1.0f, +1.0f,
  -1.0f, +1.0f, -1.0f,
  -1.0f, +1.0f, +1.0f,
  +1.0f, +1.0f, +1.0f,
  -1.0f, +1.0f, +1.0f,
  +1.0f, -1.0f, +1.0f,
]

proc setup_colors(): seq[cfloat] =
  result = newSeq[cfloat](36*3)
  for i in 0..<36:
    let phase = (i.cfloat/36.0f)
    result[3*i+0] = 0.0f * phase
    result[3*i+1] = 1.0f * phase
    result[3*i+2] = 0.5f * (1.0-phase)

var verts: cstring = """
  #version 330 core
  layout (location = 0) in vec3 vertexPosition_modelspace;
  layout (location = 1) in vec3 vertexColor;
  out vec3 fragmentColor;
  uniform mat4 MVP;

  void main() {
    //gl_Position.xyz = vertexPosition_modelspace;
    //gl_Position.w = 1.0;
    gl_Position = MVP * vec4(vertexPosition_modelspace,1);
    fragmentColor = vertexColor;
  }
"""
var frags: cstring = """
  #version 330 core
  in vec3 fragmentColor;
  out vec3 color;
  void main(){
    color = fragmentColor;
  }
"""

var player_pos, player_vel, player_acc = vec3f(0f, 0f, 0f)

var player_racc: cfloat = 0.0f
var player_rvel: cfloat = 0.0f
var player_rot : cfloat = 0.0f

proc main =
  let w = setup_glfw()

  ## chapter 1
  setup_opengl()

  ## chapter 2
  var vao = newVAO()
  var vbo = newVBO(3, cube)

  var color_buf = setup_colors()
  var colors = newVBO(3, color_buf)

  ## chapter 2 shaders
  var program = newProgram(frags, verts)

  ## chapter 3
  let aspect: float32 = width / height
  var proj: Mat4f = perspective(radians(45.0f), aspect, 0.1f, 100.0f)
  #var proj: Mat4f = ortho(-10.0f, 10.0f, -10.0f, 10.0f, 0.0f, 20.0f) # In world coordinates
  var view = lookAt(
    vec3f( 0f,  3f,  9f ), # camera pos
    vec3f( 0f,  0f,  0f ), # target
    vec3f( 0f,  1f,  0f ), # up
  )
  var model = mat4(1.0f).translate(player_pos)
  var mvp = proj * view * model
  var matrix = program.newMatrix(mvp)

  # main loop
  while not w.windowShouldClose():

    glClear GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT

    glUseProgram program.id

    model = mat4(1.0f)
      .translate(player_pos)
      .rotateY(radians(360 * player_rot))
    mvp = proj * view * model
    matrix.update mvp

    vbo.apply 0
    colors.apply 1
    vbo.draw()

    const inertia = 0.05
    player_acc = vec3f(mouse_x, mouse_y, 0) * inertia
    player_vel += player_acc
    player_pos += player_vel

    player_racc = mouse_z * inertia
    player_rvel += player_racc
    player_rot  += player_rvel

    const friction = 0.995
    player_vel *= friction
    player_rvel *= friction

    mouse_x = 0
    mouse_y = 0
    mouse_z = 0

    glDisableVertexAttribArray 0
    glDisableVertexAttribArray 1

    w.swapBuffers()
    glfwPollEvents()

  w.cleanup()

main()

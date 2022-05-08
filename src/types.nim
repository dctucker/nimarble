import nimgl/[glfw,opengl]
import glm
import std/tables

type
  Ind* = uint32

type
  VAO = object
    id: uint32
  VBO[T] = object
    id: uint32
    dimensions: cint
    n_verts*: cint
    data: seq[T]
  Shader = object
    id: uint32
    code: cstring
  Program = object
    id*: uint32
    vertex: Shader
    fragment: Shader
  Matrix = object
    id: int32
    mat*: Mat4f

proc update*(matrix: var Matrix) =
  var mat = matrix.mat
  glUniformMatrix4fv matrix.id, 1, false, mat.caddr

proc update*(matrix: var Matrix, value: Mat4f) =
  matrix.mat = value
  matrix.update()


proc newMatrix*(program: Program, mat: var Mat4f, name: string): Matrix =
  result.mat = mat
  result.id = glGetUniformLocation(program.id, name)

proc newVAO*(): VAO =
  glGenVertexArrays(1, result.id.addr)
  glBindVertexArray(result.id)

proc newVBO*[T](n: cint, data: var seq[T]): VBO[T] =
  result.data = data
  result.dimensions = n
  result.n_verts = data.len.cint div n
  glGenBuffers 1, result.id.addr
  glBindBuffer    GL_ARRAY_BUFFER, result.id
  glBufferData    GL_ARRAY_BUFFER, cint(T.sizeof * result.data.len), result.data[0].addr, GL_DYNAMIC_DRAW

proc update*[T](vbo: var VBO[T], data: var seq[T]) =
  vbo.data = data
  glBindBuffer    GL_ARRAY_BUFFER, vbo.id
  glBufferData    GL_ARRAY_BUFFER, cint(T.sizeof * vbo.data.len), vbo.data[0].addr, GL_DYNAMIC_DRAW
  #glBufferSubData GL_ARRAY_BUFFER, 0, cint(T.sizeof * vbo.data.len), vbo.data[0].addr

proc newElemVBO*[T](data: var seq[T]): VBO[T] =
  result.data = data
  result.dimensions = 1
  result.n_verts = data.len.cint
  glGenBuffers 1, result.id.addr
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, result.id
  glBufferData GL_ELEMENT_ARRAY_BUFFER, cint(T.sizeof * result.data.len), result.data[0].addr, GL_STATIC_DRAW

proc check*(shader: Shader) =
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

proc check*(program: Program) =
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

proc newShader*(kind: GLEnum, code: var cstring): Shader =
  result.id = glCreateShader kind
  result.id.glShaderSource 1'i32, code.addr, nil
  result.id.glCompileShader
  result.check

proc `=destroy`(o: var VAO) = glDeleteVertexArrays 1, o.id.addr
proc `=destroy`[T](o: var VBO[T]) = glDeleteBuffers 1, o.id.addr
proc `=destroy`(shader: var Shader) = shader.id.glDeleteShader
proc `=destroy`(program: var Program) = program.id.glDeleteProgram

proc newProgram*(frag_code, vert_code, geom_code: var cstring): Program =
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

proc apply*(vbo: VBO, n: GLuint) {.inline.} =
  glEnableVertexAttribArray n
  glBindBuffer GL_ARRAY_BUFFER, vbo.id
  glVertexAttribPointer n, vbo.dimensions, EGL_FLOAT, false, 0, nil

proc draw*(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glDrawArrays kind, 0, vbo.n_verts

proc draw_elem*(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, vbo.id
  glDrawElements kind, vbo.n_verts, GL_UNSIGNED_INT, nil

proc use*(program: Program) =
  glUseProgram program.id


type Mesh* = ref object
  pos*, vel*, acc*: Vec3f
  rot*: Quatf
  vao*: VAO
  vert_vbo*, color_vbo*: VBO[cfloat]
  elem_vbo*: VBO[Ind]
  norm_vbo*: VBO[cfloat]
  model*: Matrix
  normal*: Vec3f
  mvp*: Matrix
  program*: Program

type
  CliffMask* = enum
    XX = 0,     # regulard slope
    LL = 1,     # L is left
    JJ = 2,     # J is right
    HH,         # H is left and right
    AA = 4,     # A is up
    LA, AJ, AH,
    VV = 8,     # V is down
    LV, VJ, VH,
    II, IL, IJ, # I is top and bottom
    IH,         # oops! all cliffs
    RI, RH,     # ramps up/down, left/right
    GG,         # goal
    TU, IN, OU, # tubes
    IC,         # icy
    CU,         # copper
    SW,         # sine wave
    P1,         # player 1 start position
    P2,         # player 2 start position
    EM,         # entity: marble
    EY,         # entity: yum
    EA,         # entity: acid
    EV,         # entity: vacuum
    EP,         # entity: piston
    EH,         # entity: hammer

  Actor* = ref object
    kind*: CliffMask
    origin*: Vec3i
    mesh*: Mesh

  CubePoint* = object
    height*: float
    color*: Vec4f
    normal*: Vec3f

  Level* = ref object
    width*, height*, span*: int
    origin*: Vec3i
    clock*: int
    color*: Vec3f
    data*: seq[float]
    mask*: seq[CliffMask]
    floor_lookup*: TableRef[(cfloat, cfloat, cfloat), Ind]
    floor_colors*: seq[cfloat]
    floor_index*: seq[Ind]
    floor_verts*: seq[cfloat]
    floor_normals*: seq[cfloat]
    floor_plane*: Mesh
    actors*: seq[Actor]
    name*: string


proc cliff*(a: CliffMask): bool =
  return XX.ord < a.ord and a.ord < GG.ord

proc has*(a,b: CliffMask): bool =
  result = a == b
  if a.cliff:
    return (a.ord and b.ord) != 0

proc offset*[T:Ordinal](level: Level, i,j: T): T =
  if j >= level.width  or j < 0: return 0
  if i >= level.height or i < 0: return 0
  result = level.width * i + j

type
  GameState* = enum
    ATTRACT,
    READY,
    PLAY,
    GOAL,
    GAME_OVER,
    INITIALS,
    HALL_OF_FAME,

  MouseMode* = enum
    MouseOff,
    MouseAcc,
    MousePan,
    MouseCam,

  Player* = ref object
    mesh*: Mesh

  Game* = ref object
    state*: GameState
    score*: int
    respawns*: uint
    hourglass*: float
    level*: int32
    player*: Player
    proj*: Mat4f
    view*: Matrix
    respawn_pos*: Vec3f
    pan_vel*: Vec3f
    pan_acc*: Vec3f
    pan*: Vec3f
    pan_target*: Vec3f
    window*: GLFWWindow
    fov*: float32
    camera_distance*: float32
    camera_target*, camera_pos*, camera_up*: Vec3f
    light_pos*: Vec3f
    light_power*: float32
    light_color*: Vec3f
    light_specular_color*: Vec3f
    light_ambient_weight*: float32
    paused*: bool
    mouse_mode*: MouseMode
    following*: bool
    frame_step*: bool
    goal*: bool
    dead*: bool
    god*: bool
    wireframe*: bool

proc newGame*: Game =
  Game(
    state: ATTRACT,
    level: 1,
    player: Player(),
    fov: 30f,
    light_color: vec3f(1,1,1),
    light_specular_color: vec3f(1.0, 0.825, 0.75) * 0.375,
    light_ambient_weight: 0.875f,
    light_power: 20000f,
    camera_distance: 30f,
    paused : false,
    mouse_mode : MouseAcc,
    following : true,
    frame_step : false,
    goal : false,
    dead : false,
    wireframe : false,
  )


type
  Editor* = ref object
    visible*: bool
    level*: Level
    name*: string
    row*, col*: int
    selection*: Vec4i
    cut*: Vec4i
    width*: int
    focused*: bool
    input*: string
    cursor_mask*: bool
    cursor_data*: bool
    brush*: bool
    dirty*: bool


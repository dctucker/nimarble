import nimgl/opengl
import glm

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
    id: uint32
    vertex: Shader
    fragment: Shader
  Matrix = object
    id: int32
    matrix*: Mat4f

proc update*(matrix: Matrix, value: var Mat4f) =
  glUniformMatrix4fv matrix.id, 1, false, value.caddr

proc newMatrix*(program: Program, matrix: var Mat4f, name: string): Matrix =
  result.matrix = matrix
  result.id = glGetUniformLocation(program.id, name)
  #result.update matrix

proc newVAO*(): VAO =
  glGenVertexArrays(1, result.id.addr)
  glBindVertexArray(result.id)

proc newVBO*[T](n: cint, data: var seq[T]): VBO[T] =
  result.data = data
  result.dimensions = n
  result.n_verts = data.len.cint div n
  glGenBuffers 1, result.id.addr
  glBindBuffer GL_ARRAY_BUFFER, result.id
  glBufferData GL_ARRAY_BUFFER, cint(T.sizeof * result.data.len), result.data[0].addr, GL_STATIC_DRAW

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
  mvp*: Mat4f
  model*: Mat4f
  normal*: Vec3f
  matrix*: Matrix
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
    SW,         # sine wave
    P1,         # player 1 start position
    P2,         # player 2 start position
    EM,         # enemy: marble
    EY,         # enemy: yum
    EA,         # enemy: acid

  Actor* = ref object
    kind*: CliffMask
    origin*: Vec3i
    mesh*: Mesh

  Level* = ref object
    width*, height*: int
    origin*: Vec3i
    data*: seq[float]
    mask*: seq[CliffMask]
    color*: Vec3f
    floor_colors*: seq[cfloat]
    floor_index*: seq[Ind]
    floor_verts*: seq[cfloat]
    floor_plane*: Mesh
    clock*: int
    actors*: seq[Actor]

type
  GameState* = enum
    ATTRACT,
    READY,
    PLAY,
    GOAL,
    GAME_OVER,
    INITIALS,
    HALL_OF_FAME,

  Player* = ref object
    mesh*: Mesh

  Game* = ref object
    state*: GameState
    score*: int
    respawns*: uint
    hourglass*: float
    level*: int
    player*: Player


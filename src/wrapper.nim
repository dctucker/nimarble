import nimgl/opengl
import glm

type
  Ind* = uint32

type
  Uniform*[T] = object
    id: GLint
    data*: T
  VAO* = object
    id: uint32
  VBO*[T] = object
    id: uint32
    dimensions: cint
    n_verts*: cint
    offset*: cint
    data: ptr seq[T]
  Shader* = object
    id: uint32
    code: cstring
  Program* = object
    id*: uint32
    vertex: Shader
    fragment: Shader
  Matrix* = object
    id: int32
    mat*: Mat4f

proc get_uniform_location(program: Program, name: string): GLint =
  result = glGetUniformLocation(program.id, name)

proc get_location*(uni: var Uniform, program: Program, name: string) =
  uni.id = program.get_uniform_location(name)

proc update*[T: float32](uni: Uniform[T]) {.inline.} =
  glUniform1f uni.id, uni.data

proc update*[T: Vec3f](uni: Uniform[T]) {.inline.} =
  glUniform3f uni.id, uni.data.x, uni.data.y, uni.data.z

proc update*(matrix: var Matrix) {.inline.} =
  var mat = matrix.mat
  glUniformMatrix4fv matrix.id, 1, false, mat.caddr

proc update*(matrix: var Matrix, value: Mat4f) {.inline.} =
  matrix.mat = value
  matrix.update()


proc newMatrix*(program: Program, mat: var Mat4f, name: string): Matrix =
  result.mat = mat
  result.id = glGetUniformLocation(program.id, name)

proc newVAO*(): VAO =
  glGenVertexArrays(1, result.id.addr)
  glBindVertexArray(result.id)

proc newVBO*[T](n: cint, data: ptr seq[T]): VBO[T] =
  result.data = data
  result.dimensions = n
  result.n_verts = data[].len.cint div n
  glGenBuffers 1, result.id.addr
  glBindBuffer    GL_ARRAY_BUFFER, result.id
  glBufferData    GL_ARRAY_BUFFER, cint(T.sizeof * result.data[].len), result.data[][0].addr, GL_DYNAMIC_DRAW

proc update*[T](vbo: var VBO[T]) {.inline.} =
  glBindBuffer    GL_ARRAY_BUFFER, vbo.id
  glBufferData    GL_ARRAY_BUFFER, cint(T.sizeof * vbo.data[].len), vbo.data[][0].addr, GL_DYNAMIC_DRAW
  #glBufferSubData GL_ARRAY_BUFFER, 0, cint(T.sizeof * vbo.data[].len), vbo.data[][0].addr

proc newElemVBO*[T](data: ptr seq[T]): VBO[T] =
  result.data = data
  result.dimensions = 1
  result.n_verts = data[].len.cint
  glGenBuffers 1, result.id.addr
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, result.id
  glBufferData GL_ELEMENT_ARRAY_BUFFER, cint(T.sizeof * result.data[].len), result.data[0].addr, GL_STATIC_DRAW

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
  glDrawElements kind, vbo.n_verts, GL_UNSIGNED_INT, cast[pointer](vbo.offset * sizeof(cfloat))

proc use*(program: Program) {.inline.} =
  glUseProgram program.id


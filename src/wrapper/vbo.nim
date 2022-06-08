
type
  VBO*[T] = object
    id: uint32
    dimensions: cint
    n_verts*: cint
    offset*: cint
    data*: ptr seq[T]

proc newVBO*[T](n: cint, data: ptr seq[T]): VBO[T] =
  result.data = data
  result.dimensions = n
  result.n_verts = data[].len.cint div n
  glGenBuffers 1, result.id.addr
  glBindBuffer    GL_ARRAY_BUFFER, result.id
  glBufferData    GL_ARRAY_BUFFER, cint(T.sizeof * result.data[].len), result.data[][0].addr, GL_DYNAMIC_DRAW

proc update*[T](vbo: var VBO[T]) =
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

proc apply*(vbo: VBO, n: GLuint) =
  glEnableVertexAttribArray n
  glBindBuffer GL_ARRAY_BUFFER, vbo.id
  glVertexAttribPointer n, vbo.dimensions, EGL_FLOAT, false, 0, nil

proc draw*(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glDrawArrays kind, 0, vbo.n_verts

proc draw_elem*(vbo: VBO, kind: GLEnum = GL_TRIANGLES) {.inline.} =
  glBindBuffer GL_ELEMENT_ARRAY_BUFFER, vbo.id
  glDrawElements kind, vbo.n_verts, GL_UNSIGNED_INT, cast[pointer](vbo.offset * sizeof(cfloat))

proc `=destroy`[T](o: var VBO[T]) = glDeleteBuffers 1, o.id.addr

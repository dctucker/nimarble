
type
  VAO* = object
    id: uint32

proc newVAO*(): VAO =
  glGenVertexArrays 1, result.id.addr
  glBindVertexArray result.id

proc apply*(vao: VAO) =
  glBindVertexArray vao.id

proc `=destroy`(o: var VAO) = glDeleteVertexArrays 1, o.id.addr

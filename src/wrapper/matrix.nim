
type
  Matrix* = object
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



type
  Uniform*[T] = object
    id: GLint
    data*: T

proc get_location*(uni: var Uniform, program: Program, name: string) =
  uni.id = program.get_uniform_location(name)

proc update*[T: float32](uni: Uniform[T]) =
  glUniform1f uni.id, uni.data

proc update*[T: Vec3f](uni: Uniform[T]) =
  glUniform3f uni.id, uni.data.x, uni.data.y, uni.data.z

proc newUniform*[T](data: T) =
  return Uniform(data: data)

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
  result.id = program.get_uniform_location(name)



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


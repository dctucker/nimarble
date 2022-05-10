import glm
import wrapper

type
  Light* = object
    pos*, color*, specular*: Uniform[Vec3f]
    power*, ambient*: Uniform[float32]

proc newLight*(pos, color, specular: Vec3f, power, ambient: float32): Light =
  result = Light(
    pos      : Uniform[Vec3f](data: pos),
    color    : Uniform[Vec3f](data: color),
    specular : Uniform[Vec3f](data: specular),
    power    : Uniform[float32](data: power),
    ambient  : Uniform[float32](data: ambient),
  )

proc get_uniform_locations*(light: var Light, program: Program) =
  light.pos.get_location(program, "LightPosition_worldspace")
  light.power.get_location(program, "LightPower")
  light.color.get_location(program, "LightColor")
  light.specular.get_location(program, "SpecularColor")
  light.ambient.get_location(program, "AmbientWeight")

proc update*(light: Light) =
  light.pos.update()
  light.color.update()
  light.specular.update()
  light.power.update()
  light.ambient.update()

type
  Motion* = tuple[pos: Vec3f, vel: Vec3f, acc: Vec3f]

template liftMotion(cls, attr) =
  proc `pos=`*(obj: var cls, pos: Vec3f) = obj.attr.pos = pos
  proc `vel=`*(obj: var cls, vel: Vec3f) = obj.attr.vel = vel
  proc `acc=`*(obj: var cls, acc: Vec3f) = obj.attr.acc = acc
  proc pos*(obj: cls): var Vec3f = obj.attr.pos
  proc vel*(obj: cls): var Vec3f = obj.attr.vel
  proc acc*(obj: cls): var Vec3f = obj.attr.acc

type
  Camera* = object
    distance* : float
    max_vel*  : float
    pos*      : Vec3f
    target*   : Vec3f
    up*       : Vec3f
    vel*      : Vec3f
    pan*      : Motion

  Mesh* = ref object
    motion*: Motion
    rot*: Quatf
    vao*: VAO
    vert_vbo*, color_vbo*: VBO[cfloat]
    elem_vbo*: VBO[Ind]
    norm_vbo*: VBO[cfloat]
    model*: Matrix
    normal*: Vec3f
    mvp*: Matrix
    program*: Program

Mesh.liftMotion(motion)

proc reset*(mesh: var Mesh) =
  mesh.pos = vec3f(0f, 0f, 0f)
  mesh.vel = vec3f(0,0,0)
  mesh.acc = vec3f(0,0,0)
  mesh.rot = quatf(vec3f(0,-1,0),0).normalize
  mesh.normal = vec3f(0,-1,0)
  #mesh.rvel = vec3f(0,0,0)
  #mesh.racc = vec3f(0,0,0)

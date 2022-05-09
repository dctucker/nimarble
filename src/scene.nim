import glm
import wrapper

type
  Light* = object
    pos*, power*, color*, specular*, ambient*: Uniform[Vec3f]

  Motion* = tuple[pos: Vec3f, vel: Vec3f, acc: Vec3f]


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

proc `pos=`*(mesh: var Mesh, pos: Vec3f) = mesh.motion.pos = pos
proc `vel=`*(mesh: var Mesh, vel: Vec3f) = mesh.motion.vel = vel
proc `acc=`*(mesh: var Mesh, acc: Vec3f) = mesh.motion.acc = acc
proc pos*(mesh: Mesh): var Vec3f = mesh.motion.pos
proc vel*(mesh: Mesh): var Vec3f = mesh.motion.vel
proc acc*(mesh: Mesh): var Vec3f = mesh.motion.acc

proc reset*(mesh: var Mesh) =
  mesh.pos = vec3f(0f, 0f, 0f)
  mesh.vel = vec3f(0,0,0)
  mesh.acc = vec3f(0,0,0)
  mesh.rot = quatf(vec3f(0,-1,0),0).normalize
  mesh.normal = vec3f(0,-1,0)
  #mesh.rvel = vec3f(0,0,0)
  #mesh.racc = vec3f(0,0,0)


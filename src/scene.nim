import nimgl/opengl
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
  proc `pos=`*(obj: var cls, pos: Vec3f) {.inline.} = obj.attr.pos = pos
  proc `vel=`*(obj: var cls, vel: Vec3f) {.inline.} = obj.attr.vel = vel
  proc `acc=`*(obj: var cls, acc: Vec3f) {.inline.} = obj.attr.acc = acc
  proc pos*(obj: var cls): var Vec3f {.inline.} = return obj.attr.pos
  proc vel*(obj: var cls): var Vec3f {.inline.} = return obj.attr.vel
  proc acc*(obj: var cls): var Vec3f {.inline.} = return obj.attr.acc

type
  Pan* = object
    maxvel*   : float
    target*   : Vec3f
    motion*   : Motion

  Camera* = object
    fov*      : float32
    distance* : float
    max_vel*  : float
    target*   : Vec3f
    up*       : Vec3f
    motion*   : Motion
    pan*      : Pan

  Mesh* = ref object
    wireframe*: bool
    primitive*: GLenum
    motion*: Motion   # relative to level
    translate*: Vec3f # relative to current pos, useful for offsets
    scale*: Vec3f
    rot*: Quatf
    vao*: VAO
    textures*: TextureArray[cfloat]
    vert_vbo*, color_vbo*, uv_vbo*: VBO[cfloat]
    elem_vbo*: VBO[Ind]
    norm_vbo*: VBO[cfloat]
    model*: Matrix
    normal*: Vec3f
    mvp*: Matrix
    program*: Program

Mesh.liftMotion(motion)
Camera.liftMotion(motion)
Pan.liftMotion(motion)

proc reset*(mesh: var Mesh) =
  mesh.pos = vec3f(0f, 0f, 0f)
  mesh.vel = vec3f(0,0,0)
  mesh.acc = vec3f(0,0,0)
  mesh.scale = vec3f(1,1,1)
  mesh.rot = quatf(vec3f(0,-1,0),0).normalize
  mesh.normal = vec3f(0,-1,0)
  #mesh.rvel = vec3f(0,0,0)
  #mesh.racc = vec3f(0,0,0)

proc physics*(camera: var Camera, dt: float) {.inline.} =
  camera.pan.target += camera.pan.acc
  camera.pan.vel   = camera.pan.vel + camera.pan.acc
  camera.pan.vel.x = camera.pan.vel.x.clamp(-camera.pan.maxvel, camera.pan.maxvel)
  camera.pan.vel.y = camera.pan.vel.y.clamp(-camera.pan.maxvel, camera.pan.maxvel)
  camera.pan.vel.z = camera.pan.vel.z.clamp(-camera.pan.maxvel, camera.pan.maxvel)
  camera.pan.pos += camera.pan.vel

  let pan_delta = camera.pan.target - camera.pan.pos
  if pan_delta.length > 0f:
    if pan_delta.length < camera.maxvel:
      camera.pan.vel *= 0.9 # brake
    else:
      camera.pan.vel = pan_delta * dt
      camera.pan.vel.x = clamp(camera.pan.vel.x, -camera.maxvel, +camera.maxvel)
      camera.pan.vel.y = clamp(camera.pan.vel.y, -camera.maxvel, +camera.maxvel)
      camera.pan.vel.z = clamp(camera.pan.vel.z, -camera.maxvel, +camera.maxvel)

proc render*(mesh: var Mesh) =
  mesh.program.use()
  mesh.mvp.update
  mesh.model.update
  apply mesh.vao
  apply mesh.vert_vbo  , 0
  apply mesh.color_vbo , 1
  apply mesh.norm_vbo  , 2
  if mesh.uv_vbo.n_verts > 0:
    apply mesh.uv_vbo  , 3
  if mesh.textures.id != 0:
    apply mesh.textures
  else:
    glDisable GL_TEXTURE_2D_ARRAY

  if mesh.wireframe:
    glDisable          GL_POLYGON_OFFSET_FILL
    glPolygonMode      GL_FRONT_AND_BACK, GL_LINE
  else:
    glEnable           GL_POLYGON_OFFSET_FILL
    glPolygonOffset    1f, 1f
    glPolygonMode      GL_FRONT_AND_BACK, GL_FILL

  if mesh.elem_vbo.n_verts > 0:
    mesh.elem_vbo.draw_elem mesh.primitive
  else:
    mesh.vert_vbo.draw      mesh.primitive

  glDisableVertexAttribArray 0
  glDisableVertexAttribArray 1
  glDisableVertexAttribArray 2
  if mesh.uv_vbo.n_verts > 0:
    glDisableVertexAttribArray 3

  glBindVertexArray 0


type
  SkyBox* = ref object
    model*: Matrix
    view*: Matrix
    projection*: Matrix
    program*: Program
    vao*: VAO
    idx*: VBO[Ind]
    vbo*: VBO[cfloat]
    cubemap*: CubeMap[cfloat]

proc render*(skybox: SkyBox) =
  glDepthFunc  GL_LEQUAL
  skybox.program.use()
  skybox.projection.update
  skybox.view.update
  skybox.model.update

  glDepthMask false
  apply skybox.vao
  apply skybox.vbo, 0
  #apply skybox.vbo, 1
  #apply skybox.vbo, 2
  #apply skybox.vbo, 3
  apply skybox.cubemap
  skybox.idx.draw_elem GL_TRIANGLES
  #skybox.vbo.draw GL_TRIANGLES
  #glDrawArrays GL_TRIANGLES, 0, 36
  glDepthMask true
  glDepthFunc  GL_LESS
  glDisable    GL_TEXTURE_CUBEMAP

  glBindVertexArray 0

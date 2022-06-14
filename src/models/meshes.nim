import std/tables
import ../assets

proc newPlayerMesh: Mesh =
  Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao: newVAO(),
    vert_vbo : newVBO(3, addr sphere),
    color_vbo: newVBO(4, addr sphere_colors),
    norm_vbo : newVBO(3, addr sphere_normals),
    elem_vbo : newElemVBO( addr sphere_index),
    program: newProgram(player_frags, player_verts, player_geoms),
    translate: vec3f(0,player_radius,0)
  )

var floor_textures = newSeq[ptr seq[cfloat]]()
floor_textures.add addr mask_textures["XX"]
for m in CliffMask.low .. CliffMask.high:
  let mask = $CliffMask(m)
  let tex = addr mask_textures[mask]
  floor_textures.add tex

let wall_uv_z* = floor_textures.len

proc newFloorTextures[T](level: var Level): TextureArray[T] =
  result = newTextureArray[T](32, 64, floor_textures)
  if wall_textures.hasKey level.name:
    result.add 32, addr wall_textures[level.name]

  glGenerateMipmap GL_TEXTURE_2D_ARRAY

proc newFloorMesh(level: var Level): Mesh =
  Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao: newVAO(),
    vert_vbo  : newVBO(3, addr level.floor_verts),
    color_vbo : newVBO(4, addr level.floor_colors),
    norm_vbo  : newVBO(3, addr level.floor_normals),
    uv_vbo    : newVBO(3, addr level.floor_uvs),
    textures  : newFloorTextures[cfloat](level),
    elem_vbo  : newElemVBO(addr level.floor_index),
  )

var shared_wave_verts: VBO[cfloat]
var shared_wave_colors: VBO[cfloat]
var shared_wave_norms: VBO[cfloat]
var shared_wave_index: VBO[Ind]

proc newWaveMesh: Mesh =
  # wavelength is 12 units of 16 pixels each
  if shared_wave_verts.n_verts == 0:
    echo "init shared wave vbos"
    shared_wave_verts  = newVBO(3, addr wave_verts)
    shared_wave_colors = newVBO(4, addr wave_colors)
    shared_wave_norms  = newVBO(3, addr wave_normals)
    shared_wave_index  = newElemVBO(addr wave_index)
  Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao       : newVAO(),
    vert_vbo  : shared_wave_verts,
    color_vbo : shared_wave_colors,
    norm_vbo  : shared_wave_norms,
    elem_vbo  : shared_wave_index,
    scale     : vec3f(1f/wave_res,3,1),
  )

proc newRailMesh: Mesh =
  var verts   = single_rail
  var colors  = single_rail_colors
  var normals = single_rail_normals
  var index   = single_rail_index
  Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao       : newVAO(),
    vert_vbo  : newVBO(3, addr verts),
    color_vbo : newVBO(4, addr colors),
    norm_vbo  : newVBO(3, addr normals),
    elem_vbo  : newElemVBO(addr index),
    rot       : quatf(vec3f(1, 0, 0).normalize, 90f.radians),
    scale     : vec3f(1,1,1),
  )

proc newMesh(game: var Game, verts, colors, norms: var seq[cfloat], elems: var seq[Ind]): Mesh =
  var modelmat = mat4f(1)
  result = Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao       : newVAO(),
    vert_vbo  : newVBO(3, addr verts),
    color_vbo : newVBO(4, addr colors),
    norm_vbo  : newVBO(3, addr norms),
    elem_vbo  : newElemVBO(addr elems),
    program   : game.player.mesh.program,
    model     : game.player.mesh.program.newMatrix(modelmat, "M"),
    scale     : vec3f(1,1,1)
  )
  result.reset()

proc newCursorMesh(game: var Game): Mesh =
  newMesh( game    ,
    cursor         ,
    cursor_colors  ,
    cursor_normals ,
    cursor_index   ,
  )

proc newSelectorMesh(game: var Game): Mesh =
  newMesh( game      ,
    selector         ,
    selector_colors  ,
    selector_normals ,
    selector_index   ,
  )
proc newRampMesh(game: var Game): Mesh =
  result = newMesh( game   ,
    ramp          ,
    ramp_colors   ,
    ramp_normals  ,
    ramp_index    ,
  )
  result.uv_vbo = newVBO(3, addr ramp_uvs)
  #result.textures = newFloorTextures[cfloat](game)

proc newSkyBox(game: Game): SkyBox =
  var viewmat = game.view.mat
  var projmat = game.proj
  var modelmat = mat4f(1)#.scale(sky)
  result = SkyBox(
    vao: newVAO(),
    idx: newElemVBO(addr skybox_index),
    vbo: newVBO(3, addr skybox_verts),
    cubemap: newCubeMap[cfloat](1500, skybox_textures),
    program: newProgram(sky_frag, sky_vert, sky_geom),
    #program: game.player.mesh.program,
  )
  result.model = result.program.newMatrix(modelmat, "model")
  result.view = result.program.newMatrix(viewmat, "view")
  result.projection = result.program.newMatrix(projmat, "projection")



proc init_player*(game: var Game) =
  if game.player.mesh == nil:
    game.player.mesh = Mesh(
      primitive : GL_TRIANGLE_STRIP,
      vao: newVAO(),
      vert_vbo : newVBO(3, addr sphere),
      color_vbo: newVBO(4, addr sphere_colors),
      norm_vbo : newVBO(3, addr sphere_normals),
      elem_vbo : newElemVBO( addr sphere_index),
      program: newProgram(player_frags, player_verts, player_geoms),
      translate: vec3f(0,player_radius,0)
    )
  if game.level != nil:
    game.reset_player()

  var modelmat = mat4(1.0f)
  game.player.mesh.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * game.player.mesh.model.mat
  game.player.mesh.mvp = game.player.mesh.program.newMatrix(mvp, "MVP")


proc init_floor_plane*(game: var Game) =
  if game.level.floor_plane != nil:
    return
  load_level game.level_number
  game.level.floor_plane = Mesh(
    primitive : GL_TRIANGLE_STRIP,
    vao: newVAO(),
    vert_vbo  : newVBO(3, addr game.level.floor_verts),
    color_vbo : newVBO(4, addr game.level.floor_colors),
    norm_vbo  : newVBO(3, addr game.level.floor_normals),
    uv_vbo    : newVBO(2, addr game.level.floor_uvs),
    texture   : newTexture[cfloat](box_size, addr box_texture),
    elem_vbo  : newElemVBO(addr game.level.floor_index),
    program   : game.player.mesh.program,
  )
  var modelmat = mat4(1.0f).scale(1f, level_squash, 1f)
  game.level.floor_plane.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * game.level.floor_plane.model.mat
  game.level.floor_plane.mvp = game.level.floor_plane.program.newMatrix(mvp, "MVP")

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

var shared_wave_verts: VBO[cfloat]
var shared_wave_colors: VBO[cfloat]
var shared_wave_norms: VBO[cfloat]
var shared_wave_index: VBO[Ind]

proc newMesh(game: var Game, piece: Piece): Mesh =
  case piece.kind
  of EM:
    result = newMesh( game, sphere      , enemy_colors       , sphere_normals      , sphere_index )
    result.translate.y = player_radius
  of EY: result = newMesh( game, yum         , yum_colors         , sphere_normals      , sphere_index )
  of EA: result = newMesh( game, acid_verts  , acid_colors        , acid_normals        , acid_index   )
  of EP:
    result = newMesh( game, piston_verts, piston_colors      , piston_normals      , piston_index )
    result.rot = quatf(vec3f(1, 0, 0).normalize, 90f.radians)
    result.scale = vec3f(1f, 2f, 1f)
    result.pos = vec3f(0.5, -1.96875, 0.5)
  of GR:
    var verts   = single_rail
    var colors  = single_rail_colors
    var normals = single_rail_normals
    var index   = single_rail_index
    var modelmat = mat4f(1)
    result = Mesh(
      primitive : GL_TRIANGLE_STRIP,
      vao       : newVAO(),
      vert_vbo  : newVBO(3, addr verts),
      color_vbo : newVBO(4, addr colors),
      norm_vbo  : newVBO(3, addr normals),
      elem_vbo  : newElemVBO(addr index),
      program   : game.player.mesh.program,
      model     : game.player.mesh.program.newMatrix(modelmat, "M"),
      rot       : quatf(vec3f(1, 0, 0).normalize, 90f.radians),
      scale     : vec3f(1,1,1),
    )
    result.translate = vec3f(0.5, 0.0, 0.5)

  of SW:
    # wavelength is 12 units of 16 pixels each
    if shared_wave_verts.n_verts == 0:
      echo "init shared wave vbos"
      shared_wave_verts  = newVBO(3, addr wave_verts)
      shared_wave_colors = newVBO(4, addr wave_colors)
      shared_wave_norms  = newVBO(3, addr wave_normals)
      shared_wave_index  = newElemVBO(addr wave_index)
    var modelmat = mat4f(1)
    result = Mesh(
      primitive : GL_TRIANGLE_STRIP,
      vao       : newVAO(),
      vert_vbo  : shared_wave_verts,
      color_vbo : shared_wave_colors,
      norm_vbo  : shared_wave_norms,
      elem_vbo  : shared_wave_index,
      program   : game.player.mesh.program,
      model     : game.player.mesh.program.newMatrix(modelmat, "M"),
      scale     : vec3f(1f/wave_res,3,1),
    )
    let xm = (piece.origin.x mod wave_len).float
    let offset = cint xm * wave_ninds * wave_res
    result.elem_vbo.offset = offset
    result.elem_vbo.n_verts = wave_res * wave_ninds - 1
    result.translate.x = -xm
    result.translate.y = -1/32f
    #result.translate.z = (piece.origin.x mod 2).float * 0.125 # ugly debug

  of RI, RH:
    result = newMesh( game, ramp        , ramp_colors        , ramp_normals        , ramp_index   )
    result.translate = vec3f(0,0,0)

  else:
    result = newMesh( game, sphere      , sphere_normals     , sphere_normals      , sphere_index )

proc init_piece*[T](game: var Game, piece: var T) =
  piece.mesh = game.newMesh(piece)
  let x = (piece.origin.x - game.level.origin.x).float
  let y =  piece.origin.y.float
  let z = (piece.origin.z - game.level.origin.z).float

  if MI in game.level.map[ piece.origin.z, piece.origin.x ].masks:
    piece.mesh.scale *= 0.5
  piece.mesh.pos    += vec3f(x, y, z)
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * piece.mesh.model.mat
  piece.mesh.mvp = game.player.mesh.program.newMatrix(mvp, "MVP")

proc init_fixtures*(game: var Game) =
  for fixture in game.level.fixtures.mitems:
    if fixture.mesh != nil:
      continue
    game.init_piece(fixture)
    case fixture.kind
    of EP:
      discard#fixture.timing = level.map[fixture.origin.x, fixture.origin.z]
    else: discard

proc init_actors*(game: var Game) =
  for actor in game.level.actors.mitems:
    if actor.mesh != nil:
      continue
    game.init_piece(actor)
    case actor.kind
    of EM:
      actor.facing = vec3f(0,0,-1)
    else: discard

proc init_cursor(game: var Game) =
  editor.cursor = Cursor(
    mesh: newMesh( game, cursor        , cursor_colors        , cursor_normals        , cursor_index   ),
  )
  var cursor = editor.cursor
  var mesh = cursor.mesh
  mesh.rot = quatf(0,0,0,1)
  mesh.translate = vec3f(-0.125,0.0625,-0.125)
  mesh.scale = vec3f(1.25, 100, 1.25)
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * mesh.model.mat
  mesh.program = game.player.mesh.program
  mesh.mvp = mesh.program.newMatrix(mvp, "MVP")

proc init_selector(game: var Game) =
  editor.selector = Selector(
    mesh: newMesh( game, selector        , selector_colors        , selector_normals        , selector_index   ),
  )
  var selector = editor.selector
  var mesh = selector.mesh
  mesh.rot = quatf(0,0,0,1)
  mesh.translate = vec3f( -0.5, 0.125, -0.5 )
  mesh.scale = vec3f(1.0, 100, 1.0)
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * mesh.model.mat
  mesh.program = game.player.mesh.program
  mesh.mvp = mesh.program.newMatrix(mvp, "MVP")


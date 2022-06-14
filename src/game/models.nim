include ../models/meshes

proc init_player*(game: var Game) =
  if game.player.mesh == nil:
    game.player.mesh = newPlayerMesh()
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
  game.level.floor_plane = game.level.newFloorMesh()
  game.level.floor_plane.program = game.player.mesh.program
  var modelmat = mat4(1.0f).scale(1f, level_squash, 1f)
  game.level.floor_plane.model = game.player.mesh.program.newMatrix(modelmat, "M")
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * game.level.floor_plane.model.mat
  game.level.floor_plane.mvp = game.level.floor_plane.program.newMatrix(mvp, "MVP")

proc newMesh(game: var Game, piece: Piece): Mesh =
  case piece.kind
  of EM:
    result = newMesh( game, sphere      , enemy_colors       , sphere_normals      , sphere_index )
    result.translate.y = player_radius
  of EY: result = newMesh( game, yum         , yum_colors         , sphere_normals      , sphere_index )
  of EA:
    result = newMesh( game, acid_verts  , acid_colors        , acid_normals        , acid_index   )
    result.primitive = GL_TRIANGLE_FAN

  of EP:
    result = newMesh( game, piston_verts, piston_colors      , piston_normals      , piston_index )
    result.rot = quatf(vec3f(1, 0, 0).normalize, 90f.radians)
    result.scale = vec3f(1f, 2f, 1f)
    result.pos = vec3f(0.5, -1.96875, 0.5)
  of GR:
    result = newRailMesh()
    var modelmat = mat4f(1)
    result.program   = game.player.mesh.program
    result.model     = game.player.mesh.program.newMatrix(modelmat, "M")
    result.translate = vec3f(0.5, 0.0, 0.5)

  of SW:
    let xm = (piece.origin.x mod wave_len).float
    let offset = cint xm * wave_ninds * wave_res
    result = newWaveMesh()
    result.program = game.player.mesh.program
    var modelmat = mat4f(1)
    result.model = game.player.mesh.program.newMatrix(modelmat, "M")
    result.elem_vbo.offset = offset
    result.elem_vbo.n_verts = wave_res * wave_ninds - 1
    result.translate.x = -xm
    result.translate.y = -1/32f
    #result.translate.z = (piece.origin.x mod 2).float * 0.125 # ugly debug

  of RI, RH:
    result = game.newRampMesh()
    result.translate = vec3f(0,0,0)
    result.textures = game.level.floor_plane.textures

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
    mesh: game.newCursorMesh()
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
    mesh: game.newSelectorMesh()
  )
  var selector = editor.selector
  var mesh = selector.mesh
  mesh.rot = quatf(0,0,0,1)
  mesh.translate = vec3f( -0.5, 0.125, -0.5 )
  mesh.scale = vec3f(1.0, 100, 1.0)
  var mvp = game.proj * game.view.mat.translate(-game.camera.pan.pos) * mesh.model.mat
  mesh.program = game.player.mesh.program
  mesh.mvp = mesh.program.newMatrix(mvp, "MVP")


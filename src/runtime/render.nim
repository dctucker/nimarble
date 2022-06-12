
proc compute_model(mesh: var Mesh) =
  mesh.model.mat = mat4(1.0f)
    .translate(mesh.pos * vec3f(1,level_squash,1))
    .translate(mesh.translate)
    .scale(mesh.scale) * mesh.rot.mat4f

proc render*(game: var Game, mesh: var Mesh) =
  mesh.mvp.mat = game.proj * game.view.mat.translate(-game.camera.pan.pos) * mesh.model.mat
  mesh.render()

proc render[T: Piece](piece: var T) =
  var mesh = piece.mesh
  mesh.compute_model()

  game.render(mesh)

proc render[T: Selector](selector: var T) =
  selector.mesh.compute_model()
  game.render selector.mesh

proc render[T: Cursor](cursor: var T) =
  cursor.mesh.compute_model()
  cursor.mesh.wireframe = true
  game.render cursor.mesh
  cursor.mesh.wireframe = false
  game.render cursor.mesh
  if editor.focused:
    cursor.phase.inc

  var scale = 1.125 + 0.25 * ((cursor.phase mod 40) - 20).abs.float / 20f
  cursor.mesh.scale.xz = vec2f(scale)

proc render*(game: var Game, skybox: var SkyBox) =
  skybox.projection.mat = game.proj
  skybox.view.mat = game.view.mat.translate(vec3f(0, game.level.origin.y.float/2 - sky * 0.125, 0))
  skybox.model.mat = mat4f(1).scale(sky * 0.375)
  skybox.render()



iterator pieces_by_kind[T: Piece](s: seq[T]): (CliffMask, var seq[T]) =
  # TODO this is inefficient
  var tbl = newTable[CliffMask, seq[T]]()
  for f in s:
    if not tbl.hasKey f.kind:
      tbl[f.kind] = @[]
    tbl[f.kind].add f
  for k,v in tbl.mpairs:
    yield (k,v)

proc info_window*(actors: ActorSet) =
  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("actors")

  for kind, s in actors.pieces_by_kind:
    var k = cstring $kind
    if igCollapsingHeader(k, DefaultOpen):
      for a, actor in s.mpairs:
        var name: cstring

        name = cstring("pos##" & $a)
        igDragFloat3 name, actor.mesh.pos.arr, 0.125, -sky, sky

        name = cstring("vel##" & $a)
        igDragFloat3 name, actor.mesh.vel.arr, 0.125, -96f, 96f

        name = cstring("acc##" & $a)
        igDragFloat3 name, actor.mesh.acc.arr, 0.125, -96f, 96f

        name = cstring("scale##" & $a)
        igDragFloat3 name, actor.mesh.scale.arr, 0.125, 0f, 2f

        name = cstring("facing##" & $a)
        var dir = arctan2( actor.facing.z , actor.facing.x ).degrees
        if dir < 0: dir += 360f
        igDragFloat name, dir.addr

        igSeparator()
  igEnd()

proc info_window*(fixtures: seq[Fixture]) =
  #igSetNextWindowPos(ImVec2(x:500, y:5))
  igBegin("fixtures")
  for kind, s in fixtures.pieces_by_kind:
    var k = cstring $kind
    if igCollapsingHeader(k, DefaultOpen):
      for f, fixture in s.mpairs:

        let name = cstring "pos##" & $f
        igDragFloat3 name   , fixture.mesh.pos.arr, 0.125, -sky, sky

        let tname = cstring "translate##" & $f
        igDragFloat3 tname   , fixture.mesh.translate.arr, 0.0625, -12f, 12f

        let rotname = cstring "rot##" & $f
        if igDragFloat4(rotname, fixture.mesh.rot.arr, 1f.radians, -180f.radians, 180f.radians):
          fixture.mesh.rot = fixture.mesh.rot.normalize()

        let offname = cstring "offset##" & $f
        igDragInt  offname, fixture.mesh.elem_vbo.offset.addr, wave_ninds, 0, wave_ninds * wave_res * wave_len

        if kind == SW:
          let hname = cstring "height##" & $f
          var height: float32 = fixture.wave_height(0.0)
          igDragFloat hname, height.addr, 0.125, -sky, sky

        igSeparator()
      igSpacing()
  igEnd()



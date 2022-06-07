
proc info_player =
  igSetNextWindowSize(ImVec2(x:300f, y:400f))
  if igBegin("player"):
    var player = game.player
    var level = game.level
    var coord = player.coord
    #var lateral = player.pos.xz.length()
    #igSliderFloat "lateral_d", lateral.addr     , -sky, sky
    igDragFloat3 "pos"     , player.mesh.pos.arr   , 0.125, -sky, sky
    igDragFloat3 "vel"     , player.mesh.vel.arr   , 0.125, -sky, sky
    igDragFloat3 "acc"     , player.mesh.acc.arr   , 0.125, -sky, sky
    igDragFloat4 "rot"     , player.mesh.rot.arr   , 0.125, -sky, sky
    #igSliderFloat3 "normal" , player.mesh.normal.arr, -1.0, 1.0
    igSliderFloat3 "respawn_pos" , player.respawn_pos.arr  , -sky, sky

    var respawns = game.respawns.int32
    igSliderInt    "respawns"     , respawns.addr, 0.int32, 10.int32

    var anim_time = player.animation_time.float32
    igSliderFloat    "player clock" , anim_time.addr, 0f, 1f
    var anim = "player animation" & $player.animation
    igText    anim.cstring

    igSpacing()
    igSeparator()
    igSpacing()

    var m0 = ($level.masks_at(coord.x, coord.z)).cstring
    var m1 = ($level.masks_at(coord.x+1, coord.z)).cstring
    var m2 = ($level.masks_at(coord.x, coord.z+1)).cstring
    igText(m0, 2)
    igSameLine()
    igText(m1)
    igSameLine()
    igText(m2)

    var sl = level.slope(coord.x, coord.z)
    igDragFloat3 "slope"     , sl.arr         , -sky, sky

    igSpacing()
    igSeparator()
    igSpacing()

    var clock = level.clock.float32
    igSliderFloat  "clock"        , clock.addr, 0f, 1f

    var phase = level.phase.int32
    igSliderInt    "phase"        , phase.addr, P1.int32, P4.int32

    if igColorEdit3( "color"      , level.color.arr ):
      level.reload_colors()

    igCheckBox     "following"    , game.following.addr
    igCheckBox     "wireframe"    , game.wireframe.addr
    igCheckBox     "god"          , game.god.addr
    igSliderInt    "level #"      , game.level_number.addr, 1.int32, n_levels.int32 - 1

    #igText("average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().framerate, igGetIO().framerate)
  igEnd()


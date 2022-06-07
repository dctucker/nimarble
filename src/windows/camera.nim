
proc info_window*(camera: var Camera): bool =
  var dirty = false
  #igSetNextWindowPos(ImVec2(x:5, y:500))
  if igBegin("camera"):
    dirty = igDragFloat3("pos"       , camera.pos.arr          , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("target"    , camera.target.arr       , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("up"        , camera.up.arr           , 0.125, -sky, sky  ) or dirty
    igSeparator()
    dirty = igDragFloat3("pan.target", camera.pan.target.arr   , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("pan"       , camera.pan.pos.arr      , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("pan_vel"   , camera.pan.vel.arr      , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat3("pan_acc"   , camera.pan.acc.arr      , 0.125, -sky, sky  ) or dirty
    dirty = igDragFloat( "fov"       , camera.fov.addr         , 0.125,   0f, 360f ) or dirty
  igEnd()
  result = dirty


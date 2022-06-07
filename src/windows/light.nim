
proc info_window*(light: var Light): bool =
  var dirty = false
  if igBegin("light"):
    dirty = igDragFloat3("pos"       , light.pos.data.arr      , 0.125, -sky, +sky  ) or dirty
    dirty = igColorEdit3("color"     , light.color.data.arr                         ) or dirty
    dirty = igDragFloat( "power"     , light.power.data.addr   , 100f, 0f, 900000f  ) or dirty
    dirty = igDragFloat( "ambient"   , light.ambient.data.addr , 1/256f, 0f, 1f      ) or dirty
    dirty = igColorEdit3("specular"  , light.specular.data.arr                      ) or dirty
  igEnd()
  result = dirty

proc info_window*(mask: CliffMask) =
  var b: bool
  if igBegin("masks", b.addr, NoFocusOnAppearing):
    if igBeginTable("keymap", 2):
      for m in CliffMask.low .. CliffMask.high:
        igTableNextRow()

        let sym = ($m).cstring
        #let ico = $m.cstring
        let name = m.name().cstring
        igTableSetColumnIndex(0)
        igText(sym)
        igTableSetColumnIndex(1)
        igText(name)

    igEndTable()
  igEnd()



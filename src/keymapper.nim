import macros
import std/tables
import nimgl/imgui

from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper
import types

macro action*(procdefs: untyped): untyped =
  result = newStmtList()
  for procdef in procdefs:
    #echo "procdef = "
    #echo procdef.treerepr
    #echo ""
    procdef.expectKind({nnkPostfix, nnkProcDef})
    let name = case procdef[0].kind
    of nnkPostfix: procdef[0][1]
    of nnkIdent  : procdef[0]
    else:  procdef[0]
    let identnode = newIdentNode($name & "_handler")
    let params = procdef.params
    let stmtlist = procdef[6]
    let brack = newTree(nnkBracketExpr,
      newIdentNode("Action"),
      newTree(nnkProcTy, params, newEmptyNode()),
    )
    result.add newLetStmt(postfix(name, "*"),
      newTree(nnkObjConstr,
        brack,
        newColonExpr(newIdentNode("name"), name.toStrLit),
        newColonExpr(newIdentNode("callback"), newTree(nnkLambda,
            newEmptyNode(),
            newEmptyNode(),
            newEmptyNode(),
            params,
            newEmptyNode(),
            newEmptyNode(),
            stmtlist
          ),
        ),
      ),
    )
    #echo result.treerepr

#[
dumpTree:
  let do_nothing* = Action[proc(game: Game, press: bool)](
    name: "do_nothing",
    action: proc(game: Game, press: bool) =
      if press:
        echo "pressed!"
  )

action:
  proc do_nothing*(game: Game, press: bool) =
    stdout.write("pressed!")
]#
proc name(k: GLFWKey): string =
  if k.ord >= K0.ord and k.ord <= GraveAccent.ord:
    return $k.ord.char
  return $k

proc draw_keymap*[T](kms: varargs[OrderedTable[GLFWKey, T]]) =
  var p_open = false
  if igBegin("keymap", p_open.addr):
    if igBeginTable("keymap", 2):
      var prefix = ""
      for m,km in kms.pairs:
        if m == 1:
          prefix = "Shift+"
        for key, value in km.pairs:
          igTableNextRow()
          igTableSetColumnIndex(0)
          igText(prefix & key.name)
          igTableSetColumnIndex(1)
          igText(value.name)
    igEndTable()
  igEnd()

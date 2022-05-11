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
    let name = procdef[0][1]
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

proc name(km: KeyMap, key: GLFWKey): string =
  return km[key].name

proc draw_keymap*[T](km: OrderedTable[GLFWKey, T]) =
  var p_open = false
  let render = igBegin("keymap", p_open.addr)
  if render:
    igBeginTable("keymap", 2)
    for key, value in km.pairs:
      igTableNextRow()
      igTableSetColumnIndex(0)
      igText($key)
      igTableSetColumnIndex(1)
      igText(value.name)
    igEndTable()
  igEnd()

#dumpTree:
#  let do_nothing* = Action[proc(game: Game, press: bool)](
#    name: "do_nothing",
#    action: proc(game: Game, press: bool) =
#      if press:
#        echo "pressed!"
#  )

action:
  proc do_nothing*(game: Game, press: bool) =
    stdout.write("pressed!")


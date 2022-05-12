import macros
import std/tables
import nimgl/imgui
import strutils

from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper

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
    result.add newLetStmt(postfix(name, "*"),
      newTree(nnkObjConstr,
        newTree(nnkBracketExpr,
          newIdentNode("Action"),
          newTree(nnkProcTy, params, newEmptyNode()),
        ),
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

proc `<=`(x: char, y: GLFWKey): bool = return x.ord <= y.ord
proc `<=`(x: GLFWKey, y: char): bool = return x.ord <= y.ord
proc `>=`(x: char, y: GLFWKey): bool = return x.ord >= y.ord
proc `>=`(x: GLFWKey, y: char): bool = return x.ord >= y.ord

proc name(k: GLFWKey): string =
  if k >= '0' and k <= '`':
    return $k.ord.char
  return $k

proc draw_keymap*[T](kms: varargs[OrderedTable[GLFWKey, T]]) =
  var p_open = false
  if igBegin("keymap", p_open.addr):
    if igBeginTable("keymap", 2):
      for m,km in kms.pairs:
        for key, value in km.pairs:
          igTableNextRow()
          igTableSetColumnIndex(0)
          var kn = key.name
          if key >= '0' and key <= '`':
            if (m and 1) != 0:
              kn = kn.toUpperAscii
            else:
              kn = kn.toLowerAscii
            if (m and 2) != 0:
              kn = "^" & kn
          else:
            if (m and 1) != 0:
              kn = "S-" & kn
            if (m and 2) != 0:
              kn = "C-" & kn
          let key_name = kn.cstring
          igText(key_name)
          igTableSetColumnIndex(1)
          let action_name = value.name.replace("do_","").replace("_"," ").cstring
          igText(actionname)
    igEndTable()
  igEnd()


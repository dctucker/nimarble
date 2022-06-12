import os
import std/macros
import std/tables

macro include_all*(dir: static[string]): untyped =
  var idents: seq[NimNode] = @[]
  for kind, fn in walkDir("src/" & dir):
    if kind != pcFile: continue
    let (dir, name, ext) = fn.splitFile()
    if ext != ".nim": continue
    idents.add ident(name)
  echo $idents

  result = newTree(nnkIncludeStmt,
    newTree( nnkInfix,
      ident("/"),
      ident($dir),
      newTree(nnkBracket, idents),
    ),
  )
  #echo result.treeRepr

macro asset_table*(dir: static[string]): untyped =
  var exprs: seq[NimNode] = @[]
  for kind, fn in walkDir(dir):
    if kind != pcFile: continue
    let (dir, name, ext) = fn.splitFile()
    if ext != ".png": continue
    exprs.add newTree( nnkExprColonExpr,
      newStrLitNode(name),
      newTree( nnkCall,
        ident("staticRead"),
        newStrLitNode("../" & fn),
      ),
    )

  result = newTree( nnkCall,
    newTree( nnkDotExpr,
      newTree( nnkTableConstr, exprs ),
      ident("toTable")
    ),
  )

#dumpTree:
#  const floor_src = {
#    "XX": staticRead("../assets/textures/masks/XX.png"),
#    "IH": staticRead("../assets/textures/masks/IH.png"),
#  }.toTable()

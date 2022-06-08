import os
import std/macros

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


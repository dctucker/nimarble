{. warning[HoleEnumConv]:off .}
import std/tables

from nimgl/glfw import GLFWKey, GLFWModShift, GLFWModControl, GLFWModSuper, getClipboardString, setClipboardString
import nimgl/imgui
import math
import glm
import strutils
import std/sets

import scene
import leveldata
import types
import masks
from keymapper import action

from models import brush_colors, selector_colors
from wrapper import update

include editor/[
  coords    ,
  selection ,
  numbers   ,
  masks     ,
  stamp     ,
  cursor    ,
  clipboard ,
  window    ,
  input     ,
]

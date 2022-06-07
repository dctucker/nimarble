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

include editor/coords
include editor/selection
include editor/numbers
include editor/masks
include editor/stamp
include editor/cursor
include editor/clipboard
include editor/window
include editor/input


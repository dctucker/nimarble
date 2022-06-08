import glm
import sequtils
import strutils
import std/math
import std/sets
import std/tables
import std/algorithm

import wrapper
import types
import masks

from models import cube_normal, cube_verts, cube_colors, cube_index, wave_res, wave_nverts, middle_points, top_points
from scene import pos
import assets

const EE = 0
const sky* = 200f
const floor_span = 50

proc column_letter(j: int): string =
  result = ""
  var v = j
  var c = 0

  if j < 0:
    return ""
  if j < 26:
    return $char(j + 65)
  if j < 676:
    c = v mod 26
    v = j div 26
    return $char(v + 64) & $char(c + 65)
  else:
    return "MAX"

proc cell_name*(i,j: int): string =
  result = j.column_letter
  if i < 0:
    return
  result &= $(i + 1)


include level/[
  coords ,
  piston ,
  zones  ,
  actors ,
  read   ,
  write  ,
  color  ,
  model  ,
  game   ,
]

var levels = @[
  Level(),
  init_level("0", level_data_src(0), level_mask_src(0), vec3f( 1f  , 0.0f, 1f   )),
  init_level("1", level_data_src(1), level_mask_src(1), vec3f( 1f  , 0.8f, 0f   )),
  init_level("2", level_data_src(2), level_mask_src(2), vec3f( 0f  , 0.4f, 0.8f )),
  init_level("3", level_data_src(3), level_mask_src(3), vec3f( 0.4f, 0.4f, 0.4f )),
  init_level("4", level_data_src(4), level_mask_src(4), vec3f( 1f  , 0.267f, 0f )),
  init_level("5", level_data_src(5), level_mask_src(5), vec3f( 1f  , 1.0f, 0.0f )),
  init_level("6", level_data_src(6), level_mask_src(6), vec3f( 1.0f, 0.0f, 0.0f )),
  init_level("7", level_data_src(7), level_mask_src(7), vec3f( 1.0f, 1.0f, 0.0f )),
]
let n_levels* = levels.len()

proc load_level*(n: int) =
  if 0 < n and n < levels.len:
    if levels[n].floor_index.len == 0:
      setup_floor levels[n]

proc get_level*(n: var int32): Level =
  while n > levels.high:
    dec n
  while n < 1:
    inc n
  return levels[n]


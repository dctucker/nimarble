import sequtils

const level_dir* = "assets/levels"

const level_data_sources = @[
  staticRead("../" & level_dir & "/0.tsv"),
  staticRead("../" & level_dir & "/1.tsv"),
  staticRead("../" & level_dir & "/2.tsv"),
  staticRead("../" & level_dir & "/3.tsv"),
  staticRead("../" & level_dir & "/4.tsv"),
  staticRead("../" & level_dir & "/5.tsv"),
  staticRead("../" & level_dir & "/6.tsv"),
  staticRead("../" & level_dir & "/7.tsv"),
]

const level_mask_sources = @[
  staticRead("../" & level_dir & "/0mask.tsv"),
  staticRead("../" & level_dir & "/1mask.tsv"),
  staticRead("../" & level_dir & "/2mask.tsv"),
  staticRead("../" & level_dir & "/3mask.tsv"),
  staticRead("../" & level_dir & "/4mask.tsv"),
  staticRead("../" & level_dir & "/5mask.tsv"),
  staticRead("../" & level_dir & "/6mask.tsv"),
  staticRead("../" & level_dir & "/7mask.tsv"),
]

proc level_data_src*(l: int): string =
  return level_data_sources[l]

proc level_mask_src*(l: int): string =
  return level_mask_sources[l]

const terminus_fn = "assets/fonts/TerminusTTF.ttf"
const terminus_ttf_asset = staticRead("../" & terminus_fn)
#var terminus_ttf_asset = assetfile.getAsset(terminus_fn)
let terminus_ttf_len* = terminus_ttf_asset.len.int32
var terminus_ttf* = terminus_ttf_asset.cstring # [0].addr

import pixie
#const floor_png = staticRead "assets/textures/masks.png"
proc toCfloat(img: Image): seq[cfloat] =
  for i in 0 ..< img.height:
    for j in 0 ..< img.width:
      var c = img[j,i]
      result.add c.r.float / 255f
      result.add c.g.float / 255f
      result.add c.b.float / 255f
      result.add c.a.float / 255f

var floor_textures* = readImage("assets/textures/masks.png").toCfloat()
#var skybox_textures* = readImage("assets/textures/skybox.png").toCfloat()

const nz_src = staticRead("../assets/textures/nz.png")
const pz_src = staticRead("../assets/textures/pz.png")
const ny_src = staticRead("../assets/textures/ny.png")
const py_src = staticRead("../assets/textures/py.png")
const nx_src = staticRead("../assets/textures/nx.png")
const px_src = staticRead("../assets/textures/px.png")
var nz = nz_src.decodeImage().toCfloat()
var pz = pz_src.decodeImage().toCfloat()
var ny = ny_src.decodeImage().toCfloat()
var py = py_src.decodeImage().toCfloat()
var nx = nx_src.decodeImage().toCfloat()
var px = px_src.decodeImage().toCfloat()

var skybox_textures* = @[
  addr px,
  addr nx,
  addr py,
  addr ny,
  addr pz,
  addr nz,
]

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

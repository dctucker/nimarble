
const vert_source = readFile("src/shaders/player.vert")
var player_verts* = vert_source.cstring

const frag_source = readFile("src/shaders/player.frag")
var player_frags* = frag_source.cstring

#const geom_source = readFile("src/shaders/player.geom")
var player_geoms* = "".cstring

const sky_vert_src = readFile("src/shaders/sky.vert")
const sky_frag_src = readFile("src/shaders/sky.frag")
var sky_vert* = sky_vert_src.cstring
var sky_frag* = sky_frag_src.cstring
var sky_geom* = "".cstring


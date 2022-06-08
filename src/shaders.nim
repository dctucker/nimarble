
const vert_source = readFile("src/shaders/player.vert")
var player_verts* = vert_source.cstring

const frag_source = readFile("src/shaders/player.frag")
var player_frags* = frag_source.cstring

#const geom_source = readFile("src/shaders/player.geom")
var player_geoms* = "".cstring


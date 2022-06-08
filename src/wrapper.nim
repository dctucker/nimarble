import nimgl/opengl
import glm

type
  Ind* = uint32

include wrapper/[
  vao,
  vbo,
  shader  ,
  program ,
  uniform ,
  texture ,
]


type
  Texture*[T] = object
    id*: uint32
    width: GLsizei
    height: GLsizei
    data*: ptr seq[T]

proc newTexture*[T](n: int, data: ptr seq[T]): Texture[T] =
  result.data = data
  result.height = n.GLsizei
  result.width = n.GLsizei
  glGenTextures 1, result.id.addr
  glBindTexture GL_TEXTURE_2D, result.id
  glTexImage2D GL_TEXTURE_2D, 0.GLint, GL_RGB.GLint, result.width, result.height, 0.GLint, GL_RGB, EGL_FLOAT, result.data[][0].addr

  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT  #GL_MIRRORED_REPEAT
  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT  #GL_CLAMP_TO_BORDER #GL_CLAMP_TO_EDGE
  #var color = vec4f( 1.0f, 0.0f, 0.0f, 1.0f )
  #glTexParameterfv GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color

  glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR.ord
  glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR.ord

  glGenerateMipmap GL_TEXTURE_2D

proc apply*(tex: Texture) =
  glActiveTexture GL_TEXTURE0
  glBindTexture GL_TEXTURE_2D, tex.id


type
  TextureArray*[T] = object
    id*: uint32
    width: GLsizei
    height: GLsizei
    layers*: GLsizei
    data*: ptr seq[T]

proc newTextureArray*[T](n: int, layers: int, data: ptr seq[T]): TextureArray[T] =
  result.data = data
  result.height = n.GLsizei
  result.width = n.GLsizei
  result.layers = layers.GLsizei
  glGenTextures 1, result.id.addr
  glBindTexture GL_TEXTURE_2D_ARRAY, result.id
  glTexImage3D GL_TEXTURE_2D_ARRAY, 0.GLint, GL_RGBA.GLint, result.width, result.height,
    layers.GLsizei, 0.GLint, GL_RGBA, EGL_FLOAT, result.data[][0].addr

  for i in 0..<layers:
    glTexSubImage3D GL_TEXTURE_2D_ARRAY, 0.GLint, 0.GLint, 0.GLint, i.GLint, result.width, result.height, 1.GLsizei, GL_RGBA, EGL_FLOAT, result.data[][4*n*n*i].addr

  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT  #GL_MIRRORED_REPEAT
  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT  #GL_CLAMP_TO_BORDER #GL_CLAMP_TO_EDGE
  #var color = vec4f( 1.0f, 0.0f, 0.0f, 1.0f )
  #glTexParameterfv GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color

  glTexParameteri GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR.ord
  glTexParameteri GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR.ord

  glGenerateMipmap GL_TEXTURE_2D_ARRAY

proc apply*(tex: TextureArray) =
  glEnable GL_TEXTURE_2D_ARRAY
  glActiveTexture GL_TEXTURE0
  glBindTexture GL_TEXTURE_2D_ARRAY, tex.id

proc disable*(text: TextureArray) =
  glDisable GL_TEXTURE_2D_ARRAY


type CubeMap*[T] = object
  id*: uint32
  width: GLsizei
  height: GLsizei
  sides*: seq[ptr seq[T]]

proc newCubeMap*[T](n: int, sides: seq[ptr seq[T]]): CubeMap[T] =
  result.sides = sides
  result.width = n.GLsizei
  result.height = n.GLsizei
  glActiveTexture GL_TEXTURE0
  glEnable GL_TEXTURE_CUBE_MAP
  glGenTextures 1, result.id.addr
  glBindTexture GL_TEXTURE_CUBEMAP, result.id
  for i,side in sides.pairs:
    let s = GLenum GL_TEXTURE_CUBE_MAP_POSITIVE_X.ord + i
    glTexImage2D s, 0.GLint, GL_RGB.GLint, result.width, result.height, 0.GLsizei, GL_RGBA.GLenum, EGL_FLOAT, side[][0].addr
  glTexParameteri GL_TEXTURE_CUBEMAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR.GLint
  glTexParameteri GL_TEXTURE_CUBEMAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR.GLint
  glTexParameteri GL_TEXTURE_CUBEMAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE.GLint
  glTexParameteri GL_TEXTURE_CUBEMAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE.GLint
  glTexParameteri GL_TEXTURE_CUBEMAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE.GLint

proc apply*(tex: CubeMap) =
  glActiveTexture GL_TEXTURE0
  glEnable      GL_TEXTURE_CUBEMAP
  glBindTexture GL_TEXTURE_CUBEMAP, tex.id

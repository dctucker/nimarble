
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
  glTexImage3D GL_TEXTURE_2D_ARRAY, 0.GLint, GL_RGB.GLint, result.width, result.height,
    layers.GLsizei, 0.GLint, GL_RGB, EGL_FLOAT, result.data[][0].addr

  for i in 0..<layers:
    glTexSubImage3D GL_TEXTURE_2D_ARRAY, 0.GLint, 0.GLint, 0.GLint, i.GLint, result.width, result.height, 1.GLsizei, GL_RGB, EGL_FLOAT, result.data[][3*n*n*i].addr

  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT  #GL_MIRRORED_REPEAT
  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT  #GL_CLAMP_TO_BORDER #GL_CLAMP_TO_EDGE
  #var color = vec4f( 1.0f, 0.0f, 0.0f, 1.0f )
  #glTexParameterfv GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color

  glTexParameteri GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR.ord
  glTexParameteri GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR.ord

  glGenerateMipmap GL_TEXTURE_2D_ARRAY

proc apply*(tex: TextureArray) =
  glActiveTexture GL_TEXTURE0
  glBindTexture GL_TEXTURE_2D_ARRAY, tex.id


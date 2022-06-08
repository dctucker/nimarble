
type
  Texture*[T] = object
    id*: uint32
    width: int
    height: int
    data*: ptr seq[T]

# Black/white checkerboard
var pixels = @[
  0.0f, 0.0f, 0.0f,   1.0f, 1.0f, 1.0f,
  1.0f, 1.0f, 1.0f,   0.0f, 0.0f, 0.0f
]

proc newTexture*[T](data: ptr seq[T]): Texture[T] =
  #result.data = data
  result.data = pixels.addr
  glGenTextures 1, result.id.addr
  glBindTexture GL_TEXTURE_2D, result.id
  glTexImage2D GL_TEXTURE_2D, 0, GL_RGB, result.width, result.height, 0, GL_RGB, GL_FLOAT, result.data[][0].addr

  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT  #GL_MIRRORED_REPEAT
  #glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT  #GL_CLAMP_TO_BORDER #GL_CLAMP_TO_EDGE
  #var color = vec4f( 1.0f, 0.0f, 0.0f, 1.0f )
  #glTexParameterfv GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, color

  glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR
  glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR

  glGenerateMipmap GL_TEXTURE_2D

proc apply*(tex: Texture) =
  glActiveTexture GL_TEXTURE0
  glBindTexture GL_TEXTURE_2D, tex.id

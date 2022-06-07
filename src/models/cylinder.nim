
proc cylinderVertices*(segments: int, radius: float32 = 1, length: float32 = 1): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)
  let l2 = length / 2f

  result[2 * (segments+1)]     = vec4f(0,0,-l2,1)
  result[3 * (segments+1) + 1] = vec4f(0,0, l2,1)

  for j in 0 .. segments:
    let
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32
      y = sin(beta).float32
      top =    vec4f(vec2f(x,y) * radius,  l2, 1)
      bottom = vec4f(vec2f(x,y) * radius, -l2, 1)

    result[2*j+0] = bottom
    result[2*j+1] = top
    result[2*(segments+1) + 1 + j] = bottom
    result[3*(segments+1) + 2 + j] = top

proc cylinderNormals*(segments: int, topRadius: float32 = 1): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1)] = vec4f(0,0,-1, 0)
  result[3 * (segments+1) + 1] = vec4f(0,0, 1, 0)

  let n = vec2f(2,1-topRadius).normalize

  for j in 0 .. segments:
    let
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32
      y = sin(beta).float32

    result[2*j+0] = vec4f( vec2(x, y) * n.x, n.y, 0)
    result[2*j+1] = vec4f( vec2(x, y) * n.x, n.y, 0)
    result[2*(segments+1) + 1 + j] = vec4f(0,0,-1, 0)
    result[3*(segments+1) + 2 + j] = vec4f(0,0, 1, 0)

proc cylinderTexCoords*(segments: int): seq[Vec2f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1)] = vec2f(0.5f)
  result[3 * (segments+1) + 1] = vec2f(0.5f)

  for j in 0 .. segments:
    let
      u = (j / segments).float32
      beta = (j / segments) * 2 * PI
      x = cos(beta).float32 * 0.5f + 0.5f
      y = sin(beta).float32 * 0.5f + 0.5f

    result[2*j+0] = vec2f(u, 0)
    result[2*j+1] = vec2f(u, 1)
    result[2*(segments+1) + 1 + j] = vec2f(x,y)
    result[3*(segments+1) + 2 + j] = vec2f(x,y)

proc cylinderColors*(segments: int, color: Vec3f): seq[Vec4f] =
  result.newSeq((segments+1) * 4 + 2)

  result[2 * (segments+1) + 0] = vec4f(1f, 1f, 1f, 1)
  result[3 * (segments+1) + 1] = vec4f(1f, 1f, 1f, 1)

  for j in 0 .. segments:
    let
      u = (j / segments).float32
      beta = (j / segments) * 2 * PI
      x = cos(45f.radians + beta).float32 * 0.5f + 0.5f
      y = sin(beta).float32 * 0.5f + 0.5f

    let contrast = 0.6
    let s = y * contrast + (1f - contrast)
    result[2*j+0] = vec4f(s, s, s, 1)
    result[2*j+1] = vec4f(s, s, s, 1)
    result[2*(segments+1) + 1 + j] = vec4f(s,s,s, 1)
    result[3*(segments+1) + 2 + j] = vec4f(s,s,s, 1)

  for c in result.mitems:
    c.x *= color.x
    c.y *= color.y
    c.z *= color.z

proc cylinderIndices*(segments: int): seq[Ind] {.compileTime.} =
  result.newSeq(0)

  for i in 0 ..< segments:
    let
      i1 = Ind( i * 2 + 0 )
      i2 = Ind( i * 2 + 1 )
      i3 = Ind( i * 2 + 2 )
      i4 = Ind( i * 2 + 3 )

    result.add([i1,i3,i2,i2,i3,i4])

  var base = Ind(2 * (segments+1))

  for i in 0 ..< Ind(segments):
    let ii = i.Ind
    result.add( [ base , base + ii + 2, base + ii + 1 ] )

  base = Ind(3 * (segments+1) + 1)

  for i in 0 ..< segments:
    let ii = i.Ind
    result.add( [ base, base + ii + 1, base + ii + 2 ] )

var yum* = toCfloats cylinderVertices(nseg, 0.5f)

const rail_segs = 6
var single_rail*         = toCfloats(   cylinderVertices(rail_segs, 0.25f)      )
var single_rail_normals* = toCfloats(    cylinderNormals(rail_segs)             )
var single_rail_colors*  = toCfloats(     cylinderColors(rail_segs, vec3f(0.7f, 0.1f, 0f))         , 4 )
var single_rail_index*   =          (    cylinderIndices(rail_segs)             )

const piston_segs = 16
var piston_verts*        = toCfloats(   cylinderVertices(piston_segs, 0.375f)    )
var piston_normals*      = toCfloats(    cylinderNormals(piston_segs)           )
var piston_colors*       = toCfloats(     cylinderColors(piston_segs, vec3f(0.6f, 0.61f, 0.61f))       , 4 )
var piston_index*        =          (    cylinderIndices(piston_segs)           )

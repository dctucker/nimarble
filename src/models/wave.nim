
const wave_res* = 16
const wave_len* = 12
const wave_angles* = wave_res * wave_len
const wave_nverts* = 12
const wave_ninds*  = 12

#[  cube under curve
        2_____3
        /|   /|
       / |  / |
     4/____/5 |
      |  |_|__|
      | 0  |  /1
      |    | /
      |____|/
     6     7      ]#

proc wave_func[T](t: T): T =
  #var y0, y1: float
  #[ sinusoidal
  result = sin(radians t + 180)
  #]#

  #[ hyperbolic secant
  result = 1f / cosh(radians(4*(t - 180)))
  #]#

  # gaussian
  const a = 1f
  const b = 2f
  const c = 2f/5f
  result = a * exp -pow(t.radians-b, 2f) / (2f*c*c)
  #]#

  const epsilon = 1/256f
  if result < epsilon: result = 0

proc gen_wave_verts: seq[Vec3f] {.compileTime.} =
  for a in 0 ..< wave_len:
    for b in 0 ..< wave_res:
      let x = a * wave_res + b
      let x0 = (x + 0).float
      let x1 = (x + 1).float
      let t0 = 360f * x0 / wave_len.float / wave_res.float
      let t1 = 360f * x1 / wave_len.float / wave_res.float

      let z0 = 1f/256f
      let z1 = 255f/256f

      var y0 = wave_func t0
      var y1 = wave_func t1

      result.add vec3f(x0,  0, z0)
      result.add vec3f(x1,  0, z0)
      result.add vec3f(x0, y0, z0)
      result.add vec3f(x1, y1, z0)
      result.add vec3f(x0, y0,  0)
      result.add vec3f(x1, y1,  0)
      result.add vec3f(x0, y0,  1)
      result.add vec3f(x1, y1,  1)
      result.add vec3f(x0, y0, z1)
      result.add vec3f(x1, y1, z1)
      result.add vec3f(x0,  0, z1)
      result.add vec3f(x1,  0, z1)

const wave_color* = vec4f( 0.267, 0.6, 0.46, 1.0 )
proc gen_wave_colors: seq[Vec4f] {.compileTime.} =
  for a in 0 ..< wave_len:
    for b in 0 ..< wave_res:
      result.add wave_color
      result.add wave_color
      result.add wave_color
      result.add wave_color

      let x = a * wave_res + b
      let x0 = (x + 0).float
      let x1 = (x + 1).float
      let t0 = 360f * x0 / wave_len.float / wave_res.float
      let t1 = 360f * x1 / wave_len.float / wave_res.float

      var y0 = wave_func t0
      var y1 = wave_func t1

      let z0 = 1f/256f
      let z1 = 255f/256f

      let sx = 1f/wave_res
      let sy = 3f
      let a = vec3f(x0 * sx, y0 * sy, z0)
      let b = vec3f(x1 * sx, y1 * sy, z0)
      let c = vec3f(x0 * sx, y0 * sy, z1)
      #let d = vec3f(x1 * sx, y1 * sy, z1)

      let n0 = -normalize (b - a).cross(c - a)
      #let n1 = -normalize (d - b).cross(c - b)
      let v = n0.y

      result.add vec4f( wave_color.rgb * v, 1.0 )
      result.add vec4f( wave_color.rgb * v, 1.0 )
      result.add vec4f( wave_color.rgb * v, 1.0 )
      result.add vec4f( wave_color.rgb * v, 1.0 )

      result.add wave_color
      result.add wave_color
      result.add wave_color
      result.add wave_color

proc gen_wave_normals: seq[Vec3f] {.compileTime.} =
  for a in 0 ..< wave_len:
    for b in 0 ..< wave_res:
      let x = a * wave_res + b
      let x0 = (x + 0).float
      let x1 = (x + 1).float
      let t0 = 360f * x0 / wave_len.float / wave_res.float
      let t1 = 360f * x1 / wave_len.float / wave_res.float

      var y0 = wave_func t0
      var y1 = wave_func t1

      let z0 = 1f/256f
      let z1 = 255f/256f

      let sx = 1f/wave_res
      let sy = 3f
      let a = vec3f(x0 * sx, y0 * sy, z0)
      let b = vec3f(x1 * sx, y1 * sy, z0)
      let c = vec3f(x0 * sx, y0 * sy, z1)
      let d = vec3f(x1 * sx, y1 * sy, z1)

      let n0 = -normalize (b - a).cross(c - a)
      let n1 = -normalize (d - b).cross(c - b)

      result.add vec3f( -1,  0, -1 ).normalize
      result.add vec3f( +1,  0, -1 ).normalize
      result.add vec3f( -1,  0, -1 ).normalize
      result.add vec3f( +1,  0, -1 ).normalize
      result.add n0
      result.add n1
      result.add n0
      result.add n1
      result.add vec3f( -1,  0, +1 ).normalize
      result.add vec3f( +1,  0, +1 ).normalize
      result.add vec3f( -1,  0, +1 ).normalize
      result.add vec3f( +1,  0, +1 ).normalize

proc gen_wave_index: seq[Ind] {.compileTime.} =
  for a in 0 ..< wave_angles:
    let v = a * wave_nverts
    for n in 0 ..< wave_nverts:
      result.add Ind v + n

var wave_verts*   = toCfloats( gen_wave_verts()   , 3)
var wave_colors*  = toCfloats( gen_wave_colors()  , 4)
var wave_normals* = toCfloats( gen_wave_normals() , 3)
var wave_index*   =          ( gen_wave_index()   )

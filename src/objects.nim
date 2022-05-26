import strutils
import sequtils

import glm

type
  ModelInd* = object
    v*  : int
    vt* : int
    vn* : int

  ModelObj* = object
    v*  : seq[Vec4f] # x y,z w=1
    vt* : seq[Vec3f] # u v=0 w=0
    vn* : seq[Vec3f] # x y z
    vp* : seq[Vec3f] # u v=0 w=0
    f*  : seq[seq[ModelInd]] # v1/vt1/vn1
    l*  : seq[seq[int]]

proc format(ints: seq[int]): string =
  return ints.join(" ")

proc `$`*(n: ModelInd): string =
  return @[n.v, n.vt, n.vn].join("/")

proc format(ns: seq[ModelInd]): string =
  return ns.join(" ")

proc format_float(f: float32): string =
  return f.formatFloat(ffDecimal, 6)

proc format(v: Vec4f): string =
  return @[v.x, v.y, v.z, v.w].map(format_float).join(" ")

proc format(v: Vec3f): string =
  return @[v.x, v.y, v.z].map(format_float).join(" ")

iterator lines(obj: ModelObj): string =
  for v  in obj.v : yield "v "  & format v
  for vt in obj.vt: yield "vt " & format vt
  for vp in obj.vp: yield "vp " & format vp
  for vn in obj.vn: yield "vn " & format vn
  for f  in obj.f : yield "f "  & format f
  for l  in obj.l : yield "l "  & format l

proc format(obj: ModelObj): string =
  return obj.lines.toSeq.join("\n")

proc parse_vec2f(tokens: seq[string]): Vec2f =
  var u,v: float32
  u = tokens[0].parseFloat()
  v = tokens[1].parseFloat()
  return vec2f(u, v)

proc parse_vec3f(tokens: seq[string]): Vec3f =
  var x,y,z: float32 = 0
  if tokens.len > 0: x = tokens[0].parseFloat()
  if tokens.len > 1: y = tokens[1].parseFloat()
  if tokens.len > 2: z = tokens[2].parseFloat()
  return vec3f(x, y, z)

proc parse_vec4f(tokens: seq[string]): Vec4f =
  var x,y,z,w: float32 = 1
  if tokens.len > 0: x = tokens[0].parseFloat()
  if tokens.len > 1: y = tokens[1].parseFloat()
  if tokens.len > 2: z = tokens[2].parseFloat()
  if tokens.len > 3: w = tokens[3].parseFloat()
  return vec4f(x, y, z, w)

proc parse_ints(tokens: seq[string]): seq[int] =
  for token in tokens:
    result.add token.parseInt()

proc parse_ind(token: string): ModelInd =
  let values = token.split("/")
  if values[0].len > 0: result.v  = values[0].parseInt()
  if values[1].len > 0: result.vt = values[1].parseInt()
  if values[2].len > 0: result.vn = values[2].parseInt()

proc parse_inds(tokens: seq[string]): seq[ModelInd] =
  for token in tokens:
    result.add token.parse_ind()

proc load_obj*(src: string): ModelObj =
  for line in src.split("\n"):
    let tokens = line.split(" ")
    let values = tokens[1..^1]
    case tokens[0]
    of "v" : add result.v  , values.parse_vec4f()
    of "vt": add result.vt , values.parse_vec3f()
    of "vn": add result.vn , values.parse_vec3f()
    of "f" : add result.f  , values.parse_inds()
    of "l" : add result.l  , values.parse_ints()

const vacuum = load_obj(staticRead("../assets/models/vacuum.obj"))

when isMainModule:
  echo vacuum.format()

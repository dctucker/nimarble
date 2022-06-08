
proc sph3f*(r, θ, φ: float): Vec3f =
  result.x = r * cos(θ) * sin(φ)
  result.y = r * cos(φ)
  result.z = r * sin(θ) * sin(φ)

proc θ*(v: Vec3f): float = return arctan2(v.z, v.x)
proc φ*(v: Vec3f): float = return arccos(v.y / v.length())
proc `θ=`* (v: var Vec3f, θ: float) = v = sph3f(v.length, θ, v.φ)
proc `φ=`* (v: var Vec3f, φ: float) = v = sph3f(v.length, v.θ, φ)
proc `θ+=`*(v: var Vec3f, θ: float) = v.θ = v.θ + θ
proc `φ+=`*(v: var Vec3f, φ: float) = v.φ = v.φ + φ

proc θφ*(v: Vec3f): Vec2f =
  return vec2f(v.θ, v.φ)

proc θ*(v: Vec2f): float = return v.x
proc φ*(v: Vec2f): float = return v.y


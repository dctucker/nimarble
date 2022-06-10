import ../models

#[
x ~= -offset

               __               |
             /    \             |
           /        \           |
         /            \         |
________/              \________|
0123456789abcdef0123456789abcdef| offset = 0

                __              |
              /    \            |
            /        \          |
          /            \        |
_________/              \_______|
f0123456789abcdef0123456789abcde| offset = 31

    xm = (piece.origin.x mod wave_len).float
    offset = cint xm * wave_ninds * wave_res
    result.pos.x = -xm

    offset = (piece.origin.x mod wave_len) * wave_ninds * wave_res
    (piece.origin.x mod wave_len) = offset / (wave_ninds * wave_res)
]#

proc animate_wave(game: Game, piece: var Fixture, dt: float) =
  let max_offset = cint wave_res * wave_ninds * wave_len

  var offset = piece.mesh.elem_vbo.offset - wave_ninds
  if offset > max_offset : offset -= max_offset
  if offset < 0          : offset += max_offset

  piece.mesh.elem_vbo.offset = offset
  #piece.mesh.pos.x =  - (offset / (wave_ninds * wave_res)).float

  #let xm = (piece.origin.x mod wave_len).float
  piece.mesh.translate.x += 1f/wave_res
  if piece.mesh.translate.x > 0f:
    piece.mesh.translate.x -= wave_len


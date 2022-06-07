
var small_font*: ptr ImFont
var large_font*: ptr ImFont

#var texture = newSeq[uint8](512*512)

proc add_custom_glyph(atlas: ptr ImFontAtlas, rect_id: int32) =
  var tex_pixels: ptr[char]
  var tex_width, tex_height: int32
  atlas.getTexDataAsRGBA32(tex_pixels.addr, tex_width.addr, tex_height.addr)
  let pixels = cast[ptr UncheckedArray[uint8]](tex_pixels)
  #echo "Atlas texture: ", tex_width, "x", tex_height

  let rect = atlas.getCustomRectByIndex(rect_id)
  var c = 0x00
  const half = 7
  for i in 0 ..< rect.height.int32:
    for j in 0 ..< rect.width.int32:
      case j
      of 6: c = 0xe0
      else: c = 0xff

      case i
      of 0        : c = 0x95
      of half - 1 : c = 0xcf
      of half     : c = 0x66
      of half + 1 : c = 0xbe
      of 14       : c = 0x8d
      else        : discard

      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 0] = c.uint8
      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 1] = c.uint8
      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 2] = c.uint8
      pixels[ 4*(rect.y.int32 + i) * tex_width + 4*(rect.x.int32 + j) + 3] = c.uint8

  #[
  var image = newImage(tex_width, tex_height)
  for i in 0 ..< tex_height:
    for j in 0 ..< tex_width:
      image[j,i] = color(
        pixels[4*i*tex_width + 4*j + 0].float / 255f,
        pixels[4*i*tex_width + 4*j + 1].float / 255f,
        pixels[4*i*tex_width + 4*j + 2].float / 255f,
        pixels[4*i*tex_width + 4*j + 3].float / 255f,
      )
  image.writeFile("assets/texture.png")
  ]#

#import std/unicode
#for rune in glyphs.runes:
#  echo rune.ord.toHex()

proc setup_fonts =
  var atlas = igGetIO().fonts

  const ascii = @[ 0x1.ImWchar, 0x7f.ImWchar ]
  const blocks = @[
    0x00b0.ImWchar, 0x00b0.ImWchar,
    0x03b8.ImWchar, 0x03c6.ImWchar,
    0x2264.ImWchar, 0x2265.ImWchar,
    0x2580.ImWchar, 0x2580.ImWchar,
    0x2584.ImWchar, 0x2584.ImWchar,
    0x2588.ImWchar, 0x2588.ImWchar,
    0x258C.ImWchar, 0x258C.ImWchar,
    0x2590.ImWchar, 0x2590.ImWchar,
    0x2599.ImWchar, 0x2599.ImWchar,
    0x259B.ImWchar, 0x259C.ImWchar,
    0x259F.ImWchar, 0x259F.ImWchar,
    0x25A0.ImWchar, 0x25A0.ImWchar,
  ]
  const imwnull = @[0.ImWchar]
  var ascii_ranges = ascii          & imwnull
  var full_ranges  = ascii & blocks & imwnull

  small_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len, 14, nil, full_ranges[0].addr)
  let rect_id = atlas.addCustomRectFontGlyph(small_font, 0x25a0.ImWchar, 7, 15, 6+1)

  #small_font.
  #small_font = atlas.addFontFromFileTTF(terminus_fn, 14, nil, ranges[0].addr)
  #assert small_font != nil
  #assert small_font.isLoaded()
  large_font = atlas.addFontFromMemoryTTF(terminus_ttf, terminus_ttf_len, 36, nil, ascii_ranges[0].addr)
  #large_font = atlas.addFontFromFileTTF(terminus_fn, 36)
  #assert large_font != nil
  #assert large_font.isLoaded()
  atlas.build()

  atlas.add_custom_glyph rect_id


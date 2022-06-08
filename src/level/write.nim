
proc format(value: float): string =
  if value == value.floor:
    return $value.int
  else:
    return $value

proc format*(level: Level, value: float): string =
  return format(value)

proc format*(level: Level, value: CliffMask): string =
  return $value

proc save*(level: Level) =
  if level.name == "":
    level.name = "_"
  let span = level.span
  let data = level.data
  let mask = level.mask
  let h = level.height
  let w = level.width

  let data_fn = level_dir & "/" & level.name & ".tsv"
  let mask_fn = level_dir & "/" & level.name & "mask.tsv"
  let data_out = data_fn.open(fmWrite)
  let mask_out = mask_fn.open(fmWrite)
  for i in 0..<h:
    for j in 0..<w:
      if j >= i and j <= i + span:
        data_out.write data[i * w + j].format
      if j < w - 1:
        data_out.write "\t"
    data_out.write "\l"

    for j in 0..<w:
      let height = data[i * w + j].format
      let value = mask[i * w + j]
      if j >= i and j <= i + span:
        if value == XX:
          mask_out.write height
        else:
          mask_out.write $value
      if j < w - 1:
        mask_out.write "\t"
    mask_out.write "\l"

  data_out.close()
  mask_out.close()
  echo "Saved ", data_fn, " and ", mask_fn

proc write_new_level* =
  const height = 120
  const width = 38 + height
  var level = Level(
    name: "new",
    height: height,
    width: width,
    span: 40,
    data: newSeq[float](width * height),
    mask: newSeq[CliffMask](width * height),
  )
  for i in 2..20:
    for j in i..i+level.span:
      level.data[i * width + j] = 20
  level.save()


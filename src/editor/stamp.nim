
action:
  proc rotate_stamp(editor: var Editor) =
    let s1 = editor.stamp
    let w = s1.width
    let dim = s1.height * w
    var s2 = Stamp(
      width : s1.height,
      height: s1.width,
      data: newSeqOfCap[float](dim),
      mask: newSeqOfCap[CliffMask](dim),
    )
    for j in 0 ..< w:
      for i in countdown(s1.height - 1,  0):
        let o1 = w * i + j
        s2.data.add s1.data[o1]
        s2.mask.add s1.mask[o1].rotate()
    editor.stamp = s2

  proc flip_stamp(editor: var Editor) =
    let s1 = editor.stamp
    let w = s1.width
    let dim = s1.height * w
    var s2 = Stamp(
      width : s1.width,
      height: s1.height,
      data: newSeqOfCap[float](dim),
      mask: newSeqOfCap[CliffMask](dim),
    )
    for i in countdown(editor.stamp.height - 1, 0):
      for j in 0 ..< editor.stamp.width:
        let o = w * i + j
        s2.data.add s1.data[o]
        s2.mask.add s1.mask[o]
    editor.stamp = s2

  proc reverse_stamp(editor: var Editor) =
    let s1 = editor.stamp
    let w = s1.width
    let dim = s1.height * w
    var s2 = Stamp(
      width : s1.width,
      height: s1.height,
      data: newSeqOfCap[float](dim),
      mask: newSeqOfCap[CliffMask](dim),
    )
    for i in 0 ..< editor.stamp.height:
      for j in countdown(editor.stamp.width - 1, 0):
        let o = w * i + j
        s2.data.add s1.data[o]
        s2.mask.add s1.mask[o]
    editor.stamp = s2


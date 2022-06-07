
proc draw_goal* =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 150, y:mid.y))
  igSetNextWindowSize(ImVec2(x:300f, y:48))
  if igBegin("GOAL", nil, ImGuiWindowFlags.NoDecoration):
    igPushFont( large_font )
    igText("Level complete!")
    igPopFont()
  igEnd()

proc draw_clock*[T](clock: T) =
  let mid = middle()
  igSetNextWindowPos(ImVec2(x:mid.x - 200, y: 0))
  igSetNextWindowSize(ImVec2(x:200, y:48))
  if igBegin("CLOCK", nil, ImGuiWindowFlags(171)):
    igPushFont( large_font )
    let clk_value = 60 - (clock / 100)
    var clk = $clk_value.int
    if clk.len < 2: clk = "0" & clk
    var cclk = clk.cstring
    igTextColored ImVec4(x:0.5,y:0.1,z:0.1, w:1.0), cclk
    igPopFont()
  igEnd()


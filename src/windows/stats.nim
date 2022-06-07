
type
  Loggable[T] = ref object
    name: cstring
    values: seq[T]
    size: int32
    phase: int32
    low, high: T

proc current*[T](l: Loggable[T]): T =
  return l.values[l.phase]

proc log*[T](l: var Loggable[T], value: T) {.inline.} =
  l.phase.inc
  if l.phase >= l.values.len:
    l.phase = 0

  l.values[l.phase] = value

#[# for posterity:
proc get_loggable_value*[T](data: pointer, index: int32): T {.cdecl, varargs.} =
  return cast[ptr Loggable[T]](data).values[index]
#]#

proc plot*[T](l: var Loggable[T]) =
  let clk =
    l.values.min().formatFloat(ffDecimal, 3) & " ≤ " &
    l.current().formatFloat(ffDecimal, 3) & " ≤ " &
    l.values.max().formatFloat(ffDecimal, 3)
  var cclk = clk.cstring

  const graph_size = ImVec2(x: 128, y: 50)
  igPlotLines(l.name, l.values[0].addr, l.size, l.phase, cclk, l.low, l.high, graph_size) #, stride: int32 = sizeof(float32).int32): void {.importc: "igPlotLines_FloatPtr".}
  #igPlotEx ImGuiPlotType.Lines, l.name, get_loggable_value[T], l.addr, l.size, l.phase, cclk, l.low, l.high

proc newLoggable*[T](name: cstring, low, high: T): Loggable[T] =
  const size = 256
  result = Loggable[T](
    size: size,
    low: low,
    high: high,
    values: newSeq[T](size),
    name: name,
  )

type
  Logs = ref object
    frame_time*   : Loggable[float32]
    player_vel_y* : Loggable[float32]
    player_acc_y* : Loggable[float32]
    air*          : Loggable[float32]

var logs* = Logs(
  frame_time   : newLoggable[float32]("frame time"  ,  4f,  64f),
  player_vel_y : newLoggable[float32]("player vel.y", -64f, 64f),
  player_acc_y : newLoggable[float32]("player acc.y", -100f, 100f),
  air          : newLoggable[float32]("air"         ,  -1f, 10f),
)

iterator items*(logs: Logs): var Loggable[float32] =
  yield logs.frame_time
  yield logs.player_vel_y
  yield logs.player_acc_y
  yield logs.air

proc log_frame_time*(frame_time: float32) =
  logs.frame_time.log frame_time

proc draw_stats*[T](value: T) =
  #igSetNextWindowPos(ImVec2(x: (width - 112).float32, y: 0))
  #igSetNextWindowSize(ImVec2(x:112, y:48))

  if igBegin("stats"):#, nil, ImGuiWindowFlags(171)):
    for loggable in logs:
      loggable.plot()
  igEnd()

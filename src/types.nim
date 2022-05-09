import nimgl/[glfw,opengl]
import glm
import std/tables
import wrapper

type
  CliffMask* = enum
    XX = 0,     # regulard slope
    LL = 1,     # L is left
    JJ = 2,     # J is right
    HH,         # H is left and right
    AA = 4,     # A is up
    LA, AJ, AH,
    VV = 8,     # V is down
    LV, VJ, VH,
    II, IL, IJ, # I is top and bottom
    IH,         # oops! all cliffs
    RI, RH,     # ramps up/down, left/right
    GG,         # goal
    TU, IN, OU, # tubes
    IC,         # icy
    CU,         # copper
    SW,         # sine wave
    P1,         # player 1 start position
    P2,         # player 2 start position
    EM,         # entity: marble
    EY,         # entity: yum
    EA,         # entity: acid
    EV,         # entity: vacuum
    EP,         # entity: piston
    EH,         # entity: hammer

  Actor* = ref object
    kind*: CliffMask
    origin*: Vec3i
    mesh*: Mesh

  CubePoint* = object
    pos*: Vec3f
    color*: Vec4f
    normal*: Vec3f

  Level* = ref object
    width*, height*, span*: int
    origin*: Vec3i
    clock*: int
    color*: Vec3f
    data*: seq[float]
    mask*: seq[CliffMask]
    floor_lookup*: TableRef[(cfloat, cfloat, cfloat), Ind]
    floor_colors*: seq[cfloat]
    floor_index*: seq[Ind]
    floor_verts*: seq[cfloat]
    floor_normals*: seq[cfloat]
    floor_plane*: Mesh
    actors*: seq[Actor]
    name*: string


proc cliff*(a: CliffMask): bool =
  return XX.ord < a.ord and a.ord <= IH.ord

proc has*(a,b: CliffMask): bool =
  result = a == b
  if a.cliff and b.cliff:
    return (a.ord and b.ord) != 0

proc offset*[T:Ordinal](level: Level, i,j: T): T =
  if j >= level.width  or j < 0: return 0
  if i >= level.height or i < 0: return 0
  result = (level.width * i + j).T

type
  GameState* = enum
    ATTRACT,
    READY,
    PLAY,
    GOAL,
    GAME_OVER,
    INITIALS,
    HALL_OF_FAME,

  MouseMode* = enum
    MouseOff,
    MouseAcc,
    MousePan,
    MouseCam,

  Player* = ref object
    mesh*: Mesh

  Game* = ref object
    state*: GameState
    score*: int
    respawns*: uint
    hourglass*: float
    level*: int32
    player*: Player
    proj*: Mat4f
    view*: Matrix
    respawn_pos*: Vec3f
    pan_vel*: Vec3f
    pan_acc*: Vec3f
    pan*: Vec3f
    pan_target*: Vec3f
    window*: GLFWWindow
    fov*: float32
    camera_distance*: float32
    camera_target*, camera_pos*, camera_up*: Vec3f
    light_pos*: Vec3f
    light_power*: float32
    light_color*: Vec3f
    light_specular_color*: Vec3f
    light_ambient_weight*: float32
    paused*: bool
    mouse_mode*: MouseMode
    following*: bool
    frame_step*: bool
    goal*: bool
    dead*: bool
    god*: bool
    wireframe*: bool

proc newGame*: Game =
  Game(
    state: ATTRACT,
    level: 1,
    player: Player(),
    fov: 30f,
    light_color: vec3f(1,1,1),
    light_specular_color: vec3f(1.0, 0.825, 0.75) * 0.375,
    light_ambient_weight: 0.875f,
    light_power: 20000f,
    camera_distance: 30f,
    paused : false,
    mouse_mode : MouseAcc,
    following : true,
    frame_step : false,
    goal : false,
    dead : false,
    wireframe : false,
  )


type
  Stamp* = object
    width*, height*: int
    data*: seq[float]
    mask*: seq[CliffMask]

  Editor* = ref object
    visible*: bool
    level*: Level
    name*: string
    row*, col*: int
    selection*: Vec4i
    cut*: Vec4i
    width*: int
    focused*: bool
    input*: string
    cursor_mask*: bool
    cursor_data*: bool
    brush*: bool
    dirty*: bool
    stamp*: Stamp


proc data*(editor: Editor): var seq[float]     = editor.level.data
proc mask*(editor: Editor): var seq[CliffMask] = editor.level.mask


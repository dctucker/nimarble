import nimgl/[glfw,opengl]
import glm
import std/tables
import masks
import wrapper
from scene import Mesh, Light, newLight, Camera, Pan

type
  Piece* = ref object of RootObj
    kind*: CliffMask
    origin*: Vec3i
    mesh*: Mesh
  Actor*   = ref object of Piece
    pivot_pos*: Vec3f
    facing*: Vec3f
  Fixture* = ref object of Piece

  CubePoint* = object
    pos*: Vec3f
    color*: Vec4f
    normal*: Vec3f

  Zone* = ref object
    kind*: CliffMask
    rect*: Vec4i # e.g. vec4i( left, top, right, bottom )
    index*: seq[Ind]

  LevelPoint* = object
    height*: float
    masks*: set[CliffMask]

  LevelMap* = ref object
    points*: seq[LevelPoint]
    width*: int
    height*: int

  UpdateKind* = enum
    Actors
    Zones
    Fixtures

  LevelUpdate* = ref object
    case kind*: UpdateKind
    of Actors   : actors*   : seq[Actor]
    of Zones    : zones*    : seq[Zone]
    of Fixtures : fixtures* : seq[Fixture]


  Level* = ref object
    width*, height*, span*: int
    origin*        : Vec3i
    clock*         : float
    phase*         : CliffMask
    color*         : Vec3f
    data*          : seq[float]
    mask*          : seq[CliffMask]
    map*           : LevelMap
    floor_colors*  : seq[cfloat]
    floor_index*   : seq[Ind]
    floor_verts*   : seq[cfloat]
    floor_normals* : seq[cfloat]
    floor_plane*   : Mesh
    actors*       : seq[Actor]
    fixtures*     : seq[Fixture]
    zones*        : seq[Zone]
    name*         : string
    updates*      : seq[LevelUpdate]

proc newLevelMap*(w,h: int): LevelMap =
  return LevelMap(
    points: newSeq[LevelPoint](w*h),
    width: w,
    height: h,
  )

proc `add`*(point: var LevelPoint, mask: CliffMask) =
  point.masks.incl mask

proc cliffs*(point: LevelPoint): CliffMask =
  for cliff in point.masks * CLIFFS:
    result += cliff

proc `[]`*[T:Ordinal](map: var LevelMap, i,j: T): var LevelPoint =
  let o = i * map.width + j
  if o < 0 or o >= map.points.len:
    return map.points[0]
  return map.points[o]

proc has*(masks: set[CliffMask], mask: CliffMask): bool =
  return mask in masks

proc empty*(p: CubePoint): bool =
  return p.pos.length == 0 and p.color.length == 0 and p.normal.length == 0

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

  JoyButtons* = object
    a*: bool
    b*: bool
    y*: bool
    back*: bool
    x*: bool
    up*: bool
    down*: bool
    left*: bool
    right*: bool
    lb*: bool
    lthumb*: bool
    rb*: bool
    rthumb*: bool
    start*: bool
    xbox*: bool

  Joystick* = ref object
    id*: int
    left_thumb*: Vec2f
    right_thumb*: Vec2f
    triggers*: Vec2f
    buttons*: JoyButtons

  Animation* = enum
    None
    Respawn
    Teleport
    Break
    Dissolve
    Consume
    Shove
    Launch
    Explode

  Player* = ref object
    mesh*: Mesh
    dead*: bool
    animation*: Animation
    animation_time*: float
    teleport_dest*: Vec3f
    respawn_pos*: Vec3f

proc next*(ani: Animation): Animation =
  result = case ani
    of Dissolve,
       Explode,
       Break,
       Consume   : Respawn
    else: Animation.None

proc visible*(p: Player): bool =
  return p.animation != Teleport


type
  Game* = ref object
    state*: GameState
    score*: int
    respawns*: uint
    hourglass*: float
    level_number*: int32
    level*: Level
    player*: Player
    proj*: Mat4f
    view*: Matrix
    window*: GLFWWindow
    camera*: Camera
    light*: Light
    paused*: bool
    mouse_mode*: MouseMode
    following*: bool
    frame_step*: bool
    goal*: bool
    god*: bool
    wireframe*: bool
    recent_input*      : GLFWKey

proc newGame*: Game =
  Game(
    state: ATTRACT,
    level_number: 1,
    player: Player(),
    light: newLight(
      pos            = vec3f( 0, 200, 200 ),
      color          = vec3f(1,1,1),
      specular       = vec3f(1.0, 0.825, 0.75) * 0.375,
      ambient        = 0.875f,
      power          = 20000f,
    ),
    camera: Camera(
      fov: 30f,
      distance: 30f,
    ),
    paused : false,
    mouse_mode : MouseAcc,
    following : true,
    frame_step : false,
    goal : false,
    wireframe : false,
  )

proc pan*(game: var Game): var Pan = return game.camera.pan

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
    height*: int
    focused*: bool
    input*: string
    cursor_mask*: bool
    cursor_data*: bool
    brush*: bool
    dirty*: bool
    stamp*: Stamp
    recent_input*: GLFWKey

  Application* = ref object
    show_player*       : bool
    show_light*        : bool
    show_camera*       : bool
    show_actors*       : bool
    show_fixtures*     : bool
    show_cube_points*  : bool
    show_editor*       : bool
    show_masks*        : bool
    show_keymap*       : bool
    show_joystick*     : bool
    show_metrics*      : bool
    selected_level*    : int

proc data*(editor: Editor): var seq[float]     = editor.level.data
proc mask*(editor: Editor): var seq[CliffMask] = editor.level.mask

proc toggle*(app: var Application): bool =
  app.show_player       = not app.show_player
  app.show_light        = not app.show_light
  app.show_camera       = not app.show_camera
  app.show_actors       = not app.show_actors
  app.show_fixtures     = not app.show_fixtures
  app.show_cube_points  = not app.show_cube_points
  #app.show_editor       = not app.show_editor
  app.show_masks        = not app.show_masks
  app.show_keymap       = not app.show_keymap
  app.show_joystick     = not app.show_joystick
  return app.show_player or app.show_light or app.show_camera or app.show_actors or app.show_fixtures or app.show_cube_points

type
  Action*[T] = ref object
    name*: string
    callback*: T
  KeyMap*[T] = ref object
    map*:   Table[GLFWKey, Action[T]]

#{.experimental: "callOperator".}
#proc `()`*[T](action: Action[T], args: varargs[untyped]) =
#  action.action(args)

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
    fixtures*: seq[Fixture]
    name*: string


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
    Teleport
    Dissolve
    Eaten
    Respawn

  Player* = ref object
    mesh*: Mesh
    dead*: bool
    animation*: Animation
    animation_time*: float
    teleport_dest*: Vec3f
    respawn_pos*: Vec3f

proc next*(ani: Animation): Animation =
  result = case ani
    of Dissolve, Eaten: Respawn
    else: Animation.None

proc visible*(p: Player): bool =
  return p.animation != Teleport


type
  Game* = ref object
    state*: GameState
    score*: int
    respawns*: uint
    hourglass*: float
    level*: int32
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

proc newGame*: Game =
  Game(
    state: ATTRACT,
    level: 1,
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

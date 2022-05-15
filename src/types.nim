import macros
import nimgl/[glfw,opengl]
import glm
import std/tables
import wrapper
from scene import Mesh, Light, newLight, Camera, Pan

macro cliff_masks(body: untyped): untyped =
  body.expectKind nnkStmtList
  var fields: seq[NimNode] = @[]
  var names: seq[string] = @[]
  for n,b in body.pairs:
    case b.kind
    of nnkAsgn:
      fields.add newTree(nnkEnumFieldDef, b[0], b[1][0])
      names.add b[1][1].strVal
    of nnkCommand:
      fields.add b[0]
      names.add b[1].strVal
    else:
      b.expectKind nnkCommand
  result = newStmtList(
    newEnum(newIdentNode("CliffMask"), fields.openArray, true, false),
    newLetStmt(newIdentNode("cliff_mask_names"), newLit(names))
  )
  echo $result.repr

cliff_masks:
  XX = 0  "regular slope"
  LL = 1  "left"
  JJ = 2  "right"
  HH      "horizontal"
  AA = 4  "up"
  LA      "left+up"
  AJ      "up+right"
  AH      "up+horizontal"
  VV = 8  "down"
  LV      "left+down"
  VJ      "down+right"
  VH      "down+horizontal"
  II      "vertical"
  IL      "vertical+left"
  IJ      "vertical+right"
  IH      "oops! all cliffs"
  RI      "ramps up/down"
  RH      "left/right"
  NS      "no slope"
  GR      "guard rail"
  FL      "flag"
  GG      "goal"
  TU      "tube"
  IN      "portal in"
  OU      "portal out"
  MI      "mini"
  IC      "icy"
  CU      "copper"
  OI      "oil"
  SD      "sand"
  BH      "bumpy horizontal"
  BI      "bumpy vertical"
  SW      "sine wave"
  PH      "phased blocks"
  P1      "player 1 start position"
  P2      "player 2 start position"
  EM      "entity: marble"
  EY      "entity: yum"
  EA      "entity: acid"
  EV      "entity: vacuum"
  EP      "entity: piston"
  EH      "entity: hammer"
  EB      "entity: bird"

proc name*(mask: CliffMask): string =
  return cliff_mask_names[mask.ord]

proc cliff*(a: CliffMask): bool =
  return XX.ord < a.ord and a.ord <= IH.ord

proc has*(a,b: CliffMask): bool =
  result = a == b
  if a.cliff and b.cliff:
    return (a.ord and b.ord) != 0

proc `or`*(m1, m2: CliffMask): CliffMask =
  return CliffMask( m1.ord or m2.ord )

proc `+=`*(m: var CliffMask, m2: CliffMask) =
  m = m or m2

proc rotate*(mask: CliffMask): CliffMask =
  if mask.cliff:
    if mask.has LL: result += AA
    if mask.has AA: result += JJ
    if mask.has JJ: result += VV
    if mask.has VV: result += LL
  else:
    result = mask

type
  Piece* = ref object of RootObj
    kind*: CliffMask
    origin*: Vec3i
    mesh*: Mesh
  Actor*   = ref object of Piece
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

  Player* = ref object
    mesh*: Mesh
    dead*: bool
    timer*: int
    teleport_dest*: Vec3f
    respawn_pos*: Vec3f

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

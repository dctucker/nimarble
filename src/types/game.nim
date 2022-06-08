
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
    Stun
    Shove
    Break
    Consume
    Dissolve
    Launch
    Explode

  Player* = ref object
    mesh*: Mesh
    dead*: bool
    animation*: Animation
    animation_time*: float
    teleport_dest*: Vec3f
    respawn_pos*: Vec3f

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
    animate_next_step* : bool
    recent_input*      : GLFWKey

proc newGame*: Game =
  Game(
    state: ATTRACT,
    level_number: 1,
    player: Player(),
    light: newLight(
      #[
      pos            = vec3f( 0, 200, 200 ),
      color          = vec3f(1,1,1),
      specular       = vec3f(1.0, 0.825, 0.75) * 0.375,
      ambient        = 0.875f,
      power          = 20000f,
      ]#
      pos            = vec3f( -25, 116, 126 ),
      color          = vec3f(1,1,1),
      specular       = vec3f(1.0, 0.825, 0.75) * 0.375,
      ambient        = 0.75f,
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


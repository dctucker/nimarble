
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


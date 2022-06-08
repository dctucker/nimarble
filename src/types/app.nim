
type
  Action*[T] = ref object
    name*: string
    callback*: T
  KeyMap*[T] = ref object
    map*:   Table[GLFWKey, Action[T]]

#{.experimental: "callOperator".}
#proc `()`*[T](action: Action[T], args: varargs[untyped]) =
#  action.action(args)

type
  Application* = ref object
    show_player*       : bool
    show_light*        : bool
    show_camera*       : bool
    show_actors*       : bool
    show_fixtures*     : bool
    show_level*        : bool
    show_editor*       : bool
    show_masks*        : bool
    show_keymap*       : bool
    show_joystick*     : bool
    show_metrics*      : bool
    selected_level*    : int

proc toggle*(app: var Application): bool =
  app.show_player       = not app.show_player
  app.show_light        = not app.show_light
  app.show_camera       = not app.show_camera
  app.show_actors       = not app.show_actors
  app.show_fixtures     = not app.show_fixtures
  app.show_level        = not app.show_level
  #app.show_editor       = not app.show_editor
  app.show_masks        = not app.show_masks
  app.show_keymap       = not app.show_keymap
  app.show_joystick     = not app.show_joystick
  return
    app.show_player    or
    app.show_light     or
    app.show_camera    or
    app.show_actors    or
    app.show_fixtures  or
    app.show_level


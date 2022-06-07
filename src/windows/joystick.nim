
proc info_window*(joystick: var Joystick) =
  # TODO refactor this to use Gamepad API
  if igBegin("joystick"):
    let size = ImVec2(x: 16, y: 64)
    igSliderFloat  "left thumb x"  ,        joystick.left_thumb.x.addr  , -1,  1
    igVSliderFloat "left thumb y"  , size , joystick.left_thumb.y.addr  ,  1, -1
    igSliderFloat  "right thumb x" ,        joystick.right_thumb.x.addr , -1,  1
    igVSliderFloat "right thumb y" , size , joystick.right_thumb.y.addr ,  1, -1
    igSliderFloat2 "triggers"      ,        joystick.triggers.arr       , -1,  1
    igCheckbox     "x"             ,        joystick.buttons.x.addr
    igCheckbox     "y"             ,        joystick.buttons.y.addr
    igCheckbox     "a"             ,        joystick.buttons.a.addr
    igCheckbox     "b"             ,        joystick.buttons.b.addr
    igCheckbox     "up"            ,        joystick.buttons.up.addr
    igCheckbox     "down"          ,        joystick.buttons.down.addr
    igCheckbox     "left"          ,        joystick.buttons.left.addr
    igCheckbox     "right"         ,        joystick.buttons.right.addr
    igCheckbox     "xbox"          ,        joystick.buttons.xbox.addr
    igCheckbox     "start"         ,        joystick.buttons.start.addr
    igCheckbox     "lthumb"        ,        joystick.buttons.lthumb.addr
    igCheckbox     "rthumb"        ,        joystick.buttons.rthumb.addr
    igCheckbox     "lb"            ,        joystick.buttons.lb.addr
    igCheckbox     "rb"            ,        joystick.buttons.rb.addr
  igEnd()


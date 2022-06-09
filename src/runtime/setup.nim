
proc setup_glfw(): GLFWWindow =
  doAssert glfwInit()

  glfwWindowHint GLFWContextVersionMajor, 3
  glfwWindowHint GLFWContextVersionMinor, 3
  glfwWindowHint GLFWOpenglForwardCompat, GLFW_TRUE
  glfwWindowHint GLFWOpenglProfile, GLFW_OPENGL_CORE_PROFILE
  glfwWindowHint GLFWResizable, GLFW_FALSE
  glfwWindowHint GLFWTransparentFramebuffer, GLFW_FALSE
  glfwWindowHint GLFWSamples, 4

  #(width, height) = display_size()
  let w = glfwCreateWindow(width, height, "Nimarble", nil, nil)
  doAssert w != nil

  w.setInputMode GLFW_CURSOR_SPECIAL, GLFWCursorDisabled
  #w.setCursor GLFWCursorDisabled
  if glfwRawMouseMotionSupported() == GLFW_TRUE:
    w.setInputMode GLFW_RAW_MOUSE_MOTION, GLFW_TRUE
  discard w.setKeyCallback(keyProc)
  discard w.setCursorPosCallback(mouseProc)
  discard w.setScrollCallback(scrollProc)
  w.makeContextCurrent()
  let mid = middle()
  w.setCursorPos mid.x, mid.y
  #w.setWindowOpacity(0.9)
  result = w

  when defined(windows):
    var hwnd = w.getWin32Window()
    doAssert hwnd != nil

proc setup_opengl() =
  doAssert glInit()

  glClearColor 0f, 0f, 0.1f, 1f
  glClear      GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT
  glEnable     GL_DEPTH_TEST
  glDepthFunc  GL_LESS       # Accept fragment if it closer to the camera than the former one

  glEnable     GL_BLEND
  glBlendFunc  GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA
  #glShadeModel GL_FLAT

  glEnable     GL_LINE_SMOOTH
  glLineWidth  2f

  #glEnable    GL_CULL_FACE
  #glCullFace  GL_BACK
  #glFrontFace GL_CW

  glEnable GL_MULTISAMPLE

proc cleanup(w: GLFWWindow) {.inline.} =
  w.destroyWindow
  glfwTerminate()


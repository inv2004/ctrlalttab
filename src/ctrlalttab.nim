import consts except regAutoRunPath
import about

import winim/lean
import wNim/[wApp, wFrame, wTextCtrl]
import wAuto

import libtray

type
  HotkeyData = object
    hHook: HHOOK
    lastKeyCode: int
    lastModifiers: int
    alttab: bool
    caps: bool
    isRemapCtrlTabEnabled: bool
    isRemapCtrlPgEnabled: bool
    isRemapCapsEnabled: bool
    frame: wFrame
    hMutex: HANDLE

var hkData {.threadvar.}: HotkeyData
var tray {.threadvar.}: Tray

proc keyProc(nCode: int32, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  var processed = false
  let kbd = cast[LPKBDLLHOOKSTRUCT](lParam)

  case int wParam
  of WM_KEYUP, WM_SYSKEYUP:
    hkData.lastKeyCode = 0

    case int kbd.vkCode
    of VK_LCONTROL:
      hkData.lastModifiers = hkData.lastModifiers and (not wModCtrl)
      if hkData.alttab:
        send "{LALTUP}"
        hkData.alttab = false
    of VK_LMENU, VK_RMENU: hkData.lastModifiers = hkData.lastModifiers and (not wModAlt)
    of VK_LSHIFT, VK_RSHIFT: hkData.lastModifiers = hkData.lastModifiers and (not wModShift)
    of VK_LWIN, VK_RWIN: hkData.lastModifiers = hkData.lastModifiers and (not wModWin)
    else: discard

    if hkData.caps:
      hkData.caps = false

  of WM_KEYDOWN, WM_SYSKEYDOWN:
    case int kbd.vkCode

    of VK_LCONTROL, VK_RCONTROL, VK_LMENU, VK_RMENU, VK_LSHIFT, VK_RSHIFT, VK_LWIN, VK_RWIN:
      hkData.lastKeyCode = 0
      case int kbd.vkCode
      of VK_LCONTROL, VK_RCONTROL: hkData.lastModifiers = hkData.lastModifiers or wModCtrl
      of VK_LMENU, VK_RMENU: hkData.lastModifiers = hkData.lastModifiers or wModAlt
      of VK_LSHIFT, VK_RSHIFT: hkData.lastModifiers = hkData.lastModifiers or wModShift
      of VK_LWIN, VK_RWIN: hkData.lastModifiers = hkData.lastModifiers or wModWin
      else: discard

    else:
      if kbd.vkCode != hkData.lastKeyCode:
        if hkData.isRemapCtrlTabEnabled and hkData.lastModifiers == wModCtrl and kbd.vkCode == VK_TAB:
          send "{LCTRLUP}{LALTDOWN}{TAB}"
          hkData.alttab = true
          processed = true
        elif hkData.isRemapCapsEnabled and not hkData.caps and hkData.lastModifiers == 0 and kbd.vkCode == VK_CAPITAL:
          hkData.caps = true
          send "{LCTRLDOWN}{LSHIFTDOWN}{LCTRLUP}{LSHIFTUP}"
          processed = true
        elif hkData.isRemapCtrlPgEnabled:
          if hkData.lastModifiers == wModCtrl and kbd.vkCode == VK_OEM_4:
            send "{LCTRLDOWN}{PGUP}"
            processed = true
          elif hkData.lastModifiers == wModCtrl and kbd.vkCode == VK_OEM_6:
            send "{LCTRLDOWN}{PGDN}"
            processed = true
          elif hkData.lastModifiers == 0 and kbd.vkCode == VK_BROWSER_BACK:
            send "{PGUP}"
            processed = true
          elif hkData.lastModifiers == 0 and kbd.vkCode == VK_BROWSER_FORWARD:
            send "{PGDN}"
            processed = true
          elif hkData.lastModifiers == (wModWin or wModShift) and kbd.vkCode == VK_F23: # Lenovo AI Key:
            send "{LWINUP}{LSHIFTUP}{HOME}"
            processed = true

      hkData.lastKeyCode = kbd.vkCode

  else: discard

  result = if processed: LRESULT 1 else: CallNextHookEx(0, nCode, wParam, lParam)

proc showWindowCallBack(_: ptr Tray) {.cdecl.} =
  hkData.frame.center()
  hkData.frame.show()
  hkData.frame.setTopMost()
  hkData.frame.setTopMost(false)

proc hookCondition(): bool =
  hkData.isRemapCtrlTabEnabled or hkData.isRemapCtrlPgEnabled or hkData.isRemapCapsEnabled

proc hook() =
  if hookCondition():
    if hkData.hHook == 0:
      hkData.lastModifiers = 0
      hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)

proc unhook(force = false) =
  if not force and hookCondition():
    return
  doAssert hkData.hHook != 0
  UnhookWindowsHookEx(hkData.hHook)
  hkData.hHook = 0

template genCallback(fnName, hkDataVal: untyped, regVal: string) =
  proc fnName(item: ptr TrayMenuItem) {.cdecl.} =
    let tray = trayGetInstance()
    doAssert not tray.isNil
    hkData.hkDataVal = not bool(item.checked)
    if hkData.hkDataVal:
      regDelete(REG_PATH, regVal)
      hook()
    else:
      regWrite(REG_PATH, regVal, 1)
      unhook()
    item.checked = cint(hkData.hkDataVal)
    trayUpdate(tray)

genCallback(remapCtrlTabCallBack, isRemapCtrlTabEnabled, REG_REMAP_CTRLTAB_VAL)
genCallback(remapCtrlPgCallBack, isRemapCtrlPgEnabled, REG_REMAP_CTRLPG_VAL)
genCallback(remapCapsCallBack, isRemapCapsEnabled, REG_REMAP_CAPS)

proc screenCallBack(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  doAssert not tray.isNil
  item.checked = cint(not bool(item.checked))
  if bool(item.checked):
    regWrite(REG_PATH, REG_SCREEN_ON, 1)
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  else:
    regDelete(REG_PATH, REG_SCREEN_ON)
    SetThreadExecutionState(ES_CONTINUOUS)
  trayUpdate(tray)

proc quitCallBack(_: ptr TrayMenuItem) {.cdecl.} =
  trayExit()
  CloseHandle(hkData.hMutex)
  quit 0

proc initApp(isScreenOnEnabled: bool): wApp =
  # check register values
  hkData.isRemapCtrlTabEnabled = regRead(REG_PATH, REG_REMAP_CTRLTAB_VAL).kind == rkRegError
  hkData.isRemapCtrlPgEnabled = regRead(REG_PATH, REG_REMAP_CTRLPG_VAL).kind == rkRegError
  hkData.isRemapCapsEnabled = regRead(REG_PATH, REG_REMAP_CAPS).kind == rkRegError

  # tray
  tray = initTray(
    iconFilepath = "ctrlalttab.exe",
    # iconFilepath = "icon.ico",
    tooltip = "CtrlAltTab",
    cb = showWindowCallBack,
    menus = [
      initTrayMenuItem(text = "Remap CtrlTab", checked = hkData.isRemapCtrlTabEnabled, cb = remapCtrlTabCallBack),
      initTrayMenuItem(text = "Remap CtrlPg", checked = hkData.isRemapCtrlPgEnabled, cb = remapCtrlPgCallBack),
      initTrayMenuItem(text = "Remap Caps", checked = hkData.isRemapCapsEnabled, cb = remapCapsCallBack),
      initTrayMenuItem(text = "-"),
      initTrayMenuItem(text = "Screen On", checked = isScreenOnEnabled, cb = screenCallBack),
      initTrayMenuItem(text = "-"),
      initTrayMenuItem(text = "Quit", cb = quitCallBack)
    ]
  )
  doAssert trayInit(addr tray) == 0

  result = App(wSystemDpiAware)
  hkData.frame = Frame(title="CtrlAltTab", size=(600, 600), style = wDefaultFrameStyle or wHideTaskbar)
  #hkData.frame.disableMaximizeButton()
  hkData.frame.wEvent_Close do(event: wEvent): quitCallBack(nil)
  hkData.frame.wEvent_Minimize do(event: wEvent): hkData.frame.hide()

  # about window
  about(hkData.frame)

proc WTSRegisterSessionNotification(hWnd: HWND, dwFlags: DWORD): WINBOOL {.stdcall, dynlib: "wtsapi32", importc.}
const NOTIFY_FOR_THIS_SESSION = 0

proc hookSessionChangeMsg(msg: var wMsg, modalHwnd: HWND): int =
  if msg.message != WM_WTSSESSION_CHANGE: return
  case msg.wParam
  of WTS_SESSION_LOCK: unhook(force = true)
  of WTS_SESSION_UNLOCK: hook()
  else: discard

proc main() =
  # check running
  hkData.hMutex = CreateMutex(nil, false, APP_MUTEX_NAME)
  doAssert hkData.hMutex != 0
  defer: CloseHandle(hkData.hMutex)
  if GetLastError() == ERROR_ALREADY_EXISTS:
    quit 1

  let isScreenOnEnabled = regRead(REG_PATH, REG_SCREEN_ON).kind != rkRegError
  let app = initApp(isScreenOnEnabled)
  doAssert WTSRegisterSessionNotification(hkData.frame.mHwnd, NOTIFY_FOR_THIS_SESSION)
  app.addMessageLoopHook(hookSessionChangeMsg)

  hook()
  if isScreenOnEnabled:
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  app.mainLoop()

main()

import about

import winim/lean
import wNim/[wApp, wFrame, wTextCtrl]
import wAuto

import libtray
# import os

const regPath = r"HKEY_CURRENT_USER\SOFTWARE\CtrlAltDel"
const regRemapCtrlTab = "RemapCtrlTabDisabled"
const regRemapCtrlPg = "RemapCtrlPgDisabled"
const regRemapCaps = "RemapCapsDisabled"
const regScreenOn = "ScreenOn"

const APP_MUTEX_NAME = r"Local\CTRLALTTAB-UNIQUE-GUID-HERE"

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
        # sleep(15)  # TODO: to prevent open alt-tab on fast click
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
      let keyCode = int kbd.vkCode
      if keyCode != hkData.lastKeyCode:
        if hkData.isRemapCtrlTabEnabled and hkData.lastModifiers == wModCtrl and keyCode == VK_TAB:
          send "{LCTRLUP}{LALTDOWN}{TAB}"
          hkData.alttab = true
          processed = true
        elif hkData.isRemapCapsEnabled and not hkData.caps and hkData.lastModifiers == 0 and keyCode == VK_CAPITAL:
          hkData.caps = true
          send "{LCTRLDOWN}{LSHIFTDOWN}{LCTRLUP}{LSHIFTUP}"
          processed = true
        elif hkData.isRemapCtrlPgEnabled:
          if hkData.lastModifiers == wModCtrl and keyCode == VK_OEM_4:
            send "{LCTRLDOWN}{PGUP}"
            processed = true
          elif hkData.lastModifiers == wModCtrl and keyCode == VK_OEM_6:
            send "{LCTRLDOWN}{PGDN}"
            processed = true
          elif hkData.lastModifiers == 0 and keyCode == VK_BROWSER_BACK:
            send "{PGUP}"
            processed = true
          elif hkData.lastModifiers == 0 and keyCode == VK_BROWSER_FORWARD:
            send "{PGDN}"
            processed = true
          elif hkData.lastModifiers == (wModWin or wModShift) and keyCode == VK_F23: # Lenovo AI Key:
            send "{LWINUP}{LSHIFTUP}{HOME}"
            processed = true

      hkData.lastKeyCode = keyCode

  else: discard

  result = if processed: LRESULT 1 else: CallNextHookEx(0, nCode, wParam, lParam)

proc showWindowCallBack(_: ptr Tray) {.cdecl.} =
  hkData.frame.center()
  hkData.frame.show()
  hkData.frame.setTopMost()
  hkData.frame.setTopMost(false)

proc hook() =
  if hkData.hHook == 0:
    hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)

proc unhook() =
  if not (hkData.isRemapCtrlTabEnabled or hkData.isRemapCtrlPgEnabled or hkData.isRemapCapsEnabled):
    UnhookWindowsHookEx(hkData.hHook)
    hkData.hHook = 0

template genCallback(fnName, hkDataVal: untyped, regVal: string) =
  proc fnName(item: ptr TrayMenuItem) {.cdecl.} =
    let tray = trayGetInstance()
    doAssert not tray.isNil
    hkData.hkDataVal = not bool(item.checked)
    if hkData.hkDataVal:
      regDelete(regPath, regVal)
      hook()
    else:
      regWrite(regPath, regVal, 1)
      unhook()
    item.checked = cint(hkData.hkDataVal)
    trayUpdate(tray)

genCallback(remapCtrlTabCallBack, isRemapCtrlTabEnabled, regRemapCtrlTab)
genCallback(remapCtrlPgCallBack, isRemapCtrlPgEnabled, regRemapCtrlPg)
genCallback(remapCapsCallBack, isRemapCapsEnabled, regRemapCaps)

proc screenCallBack(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  doAssert not tray.isNil
  item.checked = cint(not bool(item.checked))
  if bool(item.checked):
    regWrite(regPath, regScreenOn, 1)
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  else:
    regDelete(regPath, regScreenOn)
    SetThreadExecutionState(ES_CONTINUOUS)
  trayUpdate(tray)

proc quitCallBack(_: ptr TrayMenuItem) {.cdecl.} =
  trayExit()
  CloseHandle(hkData.hMutex)
  quit 0

proc initApp(isScreenOnEnabled: bool): wApp =
  # check register values
  hkData.isRemapCtrlTabEnabled = regRead(regPath, regRemapCtrlTab).kind == rkRegError
  hkData.isRemapCtrlPgEnabled = regRead(regPath, regRemapCtrlPg).kind == rkRegError
  hkData.isRemapCapsEnabled = regRead(regPath, regRemapCaps).kind == rkRegError

  # tray
  let tray = initTray(
    iconFilepath = "ctrlalttab.exe",
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
  hkData.frame.wEvent_Close do(event: wEvent):
    quitCallBack(nil)
  hkData.frame.wEvent_Minimize do(event: wEvent):
    hkData.frame.hide()

  # about window
  about(hkData.frame)

proc main() =
  # check running
  hkData.hMutex = CreateMutex(nil, false, APP_MUTEX_NAME)
  doAssert hkData.hMutex != 0
  defer: CloseHandle(hkData.hMutex)
  if GetLastError() == ERROR_ALREADY_EXISTS:
    quit 1

  let isScreenOnEnabled = regRead(regPath, regScreenOn).kind != rkRegError
  let app = initApp(isScreenOnEnabled)

  if hkData.isRemapCtrlTabEnabled or hkData.isRemapCtrlPgEnabled or hkData.isRemapCapsEnabled:
    hook()
  if isScreenOnEnabled:
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  app.mainLoop()

main()

import winim/[lean, inc/shellapi]
import wNim/[wApp, wFrame, wTextCtrl]
import wAuto

import libtray

import std/with
import os

const regPath = r"HKEY_CURRENT_USER\SOFTWARE\CtrlAltDel"
const regRemapCtrlTab = "RemapCtrlTabDisabled"
const regRemapCtrlPg = "RemapCtrlPgDisabled"
const regRemapCaps = "RemapCapsDisabled"
const regScreenOn = "ScreenOn"

const url = "https://github.com/inv2004/ctrlalttab"
const authorUrl = "https://github.com/inv2004"

const APP_MUTEX_NAME = r"Local\CTRLALTTAB-UNIQUE-GUID-HERE"

type
  HotkeyData = object
    hHook: HHOOK
    lastKeyCode: int
    lastModifiers: int
    alttab: bool
    isRemapCtrlTabEnabled: bool
    isRemapCtrlPgEnabled: bool
    isRemapCapsEnabled: bool
    frame: wFrame
    hMutex: HANDLE

var hkData {.threadvar.}: HotkeyData

proc keyProc(nCode: int32, wParam: WPARAM, lParam: LPARAM): LRESULT {.stdcall.} =
  var processed = false
  let kbd = cast[LPKBDLLHOOKSTRUCT](lParam)
  defer:
    result = if processed: LRESULT 1 else: CallNextHookEx(0, nCode, wParam, lParam)

  case int wParam
  of WM_KEYUP, WM_SYSKEYUP:
    hkData.lastKeyCode = 0
    var isMod = false

    case int kbd.vkCode
    of VK_LCONTROL, VK_RCONTROL:
      hkData.lastModifiers = hkData.lastModifiers and (not wModCtrl)
      isMod = true
      if hkData.alttab:
        sleep(15)  # TODO: to prevent open alt-tab on fast click
        send "{ENTER}"
        hkData.alttab = false
    of VK_LMENU, VK_RMENU: hkData.lastModifiers = hkData.lastModifiers and (not wModAlt); isMod = true
    of VK_LSHIFT, VK_RSHIFT: hkData.lastModifiers = hkData.lastModifiers and (not wModShift); isMod = true
    of VK_LWIN, VK_RWIN: hkData.lastModifiers = hkData.lastModifiers and (not wModWin); isMod = true
    else: discard

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
      var modifiers = 0
      if hkData.lastModifiers != 0:
        if (GetAsyncKeyState(VK_CONTROL) and 0x8000) != 0: modifiers = modifiers or wModCtrl
        if (GetAsyncKeyState(VK_MENU) and 0x8000) != 0: modifiers = modifiers or wModAlt
        if (GetAsyncKeyState(VK_SHIFT) and 0x8000) != 0: modifiers = modifiers or wModShift
        if (GetAsyncKeyState(VK_LWIN) and 0x8000) != 0 or (GetAsyncKeyState(VK_RWIN) and 0x8000) != 0: modifiers = modifiers or wModWin
        hkData.lastModifiers = modifiers

      if keyCode != hkData.lastKeyCode:
        if modifiers == wModCtrl:
          case keyCode
          of VK_TAB:
            if hkData.isRemapCtrlTabEnabled:
              send "!{TAB}"
              processed = true
              hkData.alttab = true
          of 219:
            if hkData.isRemapCtrlPgEnabled:
              send "{LCTRLDOWN}{PGUP}"
              processed = true
          of 221:
            if hkData.isRemapCtrlPgEnabled:
              send "{LCTRLDOWN}{PGDN}"
              processed = true
          else:
            discard
        elif modifiers == (wModWin or wModShift) and keyCode == VK_F23: # Lenovo AI Key
          send "{LWINUP}{LSHIFTUP}{HOME}"
          processed = true
        elif modifiers == 0 and keyCode == VK_CAPITAL: # CAPS
          if hkData.isRemapCapsEnabled:
            send "{LCTRLDOWN}{LSHIFT}{LCTRLUP}"
            processed = true
        elif modifiers == 0 and keyCode == VK_BROWSER_BACK:
            send "{PGUP}"
            processed = true
        elif modifiers == 0 and keyCode == VK_BROWSER_FORWARD:
            send "{PGDN}"
            processed = true
        else:
          discard

      hkData.lastKeyCode = keyCode

  else: discard

proc showWindow_cb(_: ptr Tray) {.cdecl.} =
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

proc remapCtrlTab_cb(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  doAssert not tray.isNil

  hkData.isRemapCtrlTabEnabled = not bool(item.checked)

  if hkData.isRemapCtrlTabEnabled:
    regDelete(regPath, regRemapCtrlTab)
    hook()
  else:
    regWrite(regPath, regRemapCtrlTab, 1)
    unhook()

  item.checked = cint(hkData.isRemapCtrlTabEnabled)
  trayUpdate(tray)

proc remapCtrlPg_cb(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  doAssert not tray.isNil

  hkData.isRemapCtrlPgEnabled = not bool(item.checked)

  if hkData.isRemapCtrlPgEnabled:
    regDelete(regPath, regRemapCtrlPg)
    hook()
  else:
    regWrite(regPath, regRemapCtrlPg, 1)
    unhook()

  item.checked = cint(hkData.isRemapCtrlPgEnabled)
  trayUpdate(tray)

proc remapCaps_cb(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  doAssert not tray.isNil

  hkData.isRemapCapsEnabled = not bool(item.checked)

  if hkData.isRemapCapsEnabled:
    regDelete(regPath, regRemapCaps)
    hook()
  else:
    regWrite(regPath, regRemapCaps, 1)
    unhook()

  item.checked = cint(hkData.isRemapCapsEnabled)
  trayUpdate(tray)

proc screen_cb(item: ptr TrayMenuItem) {.cdecl.} =
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

proc quit_cb(_: ptr TrayMenuItem) {.cdecl.} =
  trayExit()
  CloseHandle(hkData.hMutex)
  quit 0

proc main() =
  # check running
  hkData.hMutex = CreateMutex(nil, false, APP_MUTEX_NAME)
  doAssert hkData.hMutex != 0
  defer: CloseHandle(hkData.hMutex)
  if GetLastError() == ERROR_ALREADY_EXISTS:
    quit 1

  # check register values
  hkData.isRemapCtrlTabEnabled = regRead(regPath, regRemapCtrlTab).kind == rkRegError
  hkData.isRemapCtrlPgEnabled = regRead(regPath, regRemapCtrlPg).kind == rkRegError
  hkData.isRemapCapsEnabled = regRead(regPath, regRemapCaps).kind == rkRegError
  let isScreenOnEnabled = regRead(regPath, regScreenOn).kind != rkRegError

  # tray
  let tray = initTray(
    iconFilepath = "icon.ico",
    tooltip = "CtrlAltTab",
    cb = showWindow_cb,
    menus = [
      initTrayMenuItem(text = "Remap CtrlTab", checked = hkData.isRemapCtrlTabEnabled, cb = remapCtrlTab_cb),
      initTrayMenuItem(text = "Remap CtrlPg", checked = hkData.isRemapCtrlPgEnabled, cb = remapCtrlPg_cb),
      initTrayMenuItem(text = "Remap Caps", checked = hkData.isRemapCapsEnabled, cb = remapCaps_cb),
      initTrayMenuItem(text = "-"),
      initTrayMenuItem(text = "Screen On", checked = isScreenOnEnabled, cb = screen_cb),
      initTrayMenuItem(text = "-"),
      initTrayMenuItem(text = "Quit", cb = quit_cb)
    ]
  )
  doAssert trayInit(addr tray) == 0

  let app = App(wSystemDpiAware)
  hkData.frame = Frame(title="CtrlAltTab", size=(400, 300), style = wDefaultFrameStyle or wHideTaskbar)

  # about window
  let textCtrl = TextCtrl(hkData.frame, style=wTeRich or wTeMultiLine or wTeReadOnly or wTeCentre)
  with textCtrl:
    setStyle(lineSpacing=1.5)
    writeText("\n")
    writeText("CtrlAltTab shortcut remapper\n")
    writeLink(url, url)
    writeText("\n")
    writeText("Author\n")
    writeLink(authorUrl, authorUrl)
    writeText("\n")
    resetStyle()

  textctrl.wEvent_TextLink do (event: wEvent):
    if event.mouseEvent == wEvent_LeftUp:
      ShellExecute(0, "open", textctrl.range(event.start..<event.end), nil, nil, 5)

  # start
  if hkData.isRemapCtrlTabEnabled or hkData.isRemapCtrlPgEnabled:
    hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)
  if isScreenOnEnabled:
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  app.mainLoop()

main()

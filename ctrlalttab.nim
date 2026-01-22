import winim/lean
import wNim/[wApp, wFrame]
import wAuto

import libtray

import os

type
  HotkeyData = object
    hHook: HHOOK
    lastKeyCode: int
    lastModifiers: int
    alttab: bool

var hkData {.threadvar.}: HotkeyData
var frame {.threadvar.}: wFrame
var tray {.threadvar.}: Tray

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
        sleep(10)  # TODO: to prevent open alt-tab on fast click
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
            send "!{TAB}"
            processed = true
            hkData.alttab = true
          of 219:
            send "{LCTRLDOWN}{PGUP}"
            processed = true
          of 221:
            send "{LCTRLDOWN}{PGDN}"
            processed = true
          else:
            discard
        elif modifiers == 12 and keyCode == VK_F23: # Win+Shift+F23
          send "{LWINUP}{LSHIFTUP}{HOME}"
          processed = true
        elif keyCode == VK_CAPITAL: # CAPS
          send "{LCTRLDOWN}{LSHIFT}{LCTRLUP}"
          processed = true
        else:
          discard

      hkData.lastKeyCode = keyCode

  else: discard

proc window_cb(_: ptr Tray) {.cdecl.} =
  discard

proc remap_cb(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  item.checked = cint(not bool(item.checked))
  if bool(item.checked):
    hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)
  else:
    echo UnhookWindowsHookEx(hkData.hHook)
  if not tray.isNil: trayUpdate(tray)

proc screen_cb(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  item.checked = cint(not bool(item.checked))
  if bool(item.checked):
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  else:
    SetThreadExecutionState(ES_CONTINUOUS)
  if not tray.isNil: trayUpdate(tray)

proc quit_cb(_: ptr TrayMenuItem) {.cdecl.} =
  trayExit()
  quit 0

tray = initTray(
  iconFilepath = "icon.ico",
  tooltip = "CtrlAltTab",
  cb = window_cb,
  menus = [
    initTrayMenuItem(text = "Remap Alt-Tab", checked = true, cb = remap_cb),
    initTrayMenuItem(text = "Screen On", checked = true, cb = screen_cb),
    initTrayMenuItem(text = "-"),
    initTrayMenuItem(text = "Quit", cb = quit_cb)
  ]
)

proc main() =
  if trayInit(addr tray) != 0: quit 1
  let app = App(wSystemDpiAware)
  discard Frame(title="ctrl-alt-tab", size=(400, 200), style = wDefaultFrameStyle or wHideTaskbar)
  SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)
  app.mainLoop()

main()

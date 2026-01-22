import winim/[lean, inc/shellapi]
import wNim/[wApp, wFrame, wTextCtrl]
import wAuto

import libtray

import std/with
import os

const regPath = r"HKEY_CURRENT_USER\SOFTWARE\CtrlAltDel"
const regRemap = "RemapDisabled"
const regScreenOn = "ScreenOn"

const url = "https://github.com/inv2004/ctrlalttab"
const authorUrl = "https://github.com/inv2004"

type
  HotkeyData = object
    hHook: HHOOK
    lastKeyCode: int
    lastModifiers: int
    alttab: bool

var hkData {.threadvar.}: HotkeyData
var frame {.threadvar.}: wFrame

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
  frame.center()
  frame.show()

proc remap_cb(item: ptr TrayMenuItem) {.cdecl.} =
  let tray = trayGetInstance()
  doAssert not tray.isNil

  item.checked = cint(not bool(item.checked))
  if bool(item.checked):
    regDelete(regPath, regRemap)
    hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)
  else:
    regWrite(regPath, regRemap, 1)
    UnhookWindowsHookEx(hkData.hHook)
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
  quit 0

proc main() =
  # check register values
  let isRemapEnabled = regRead(regPath, regRemap).kind == rkRegError
  let isScreenOnEnabled = regRead(regPath, regScreenOn).kind != rkRegError

  # tray
  let tray = initTray(
    iconFilepath = "icon.ico",
    tooltip = "CtrlAltTab",
    cb = window_cb,
    menus = [
      initTrayMenuItem(text = "Remap CtrlAltTab", checked = isRemapEnabled, cb = remap_cb),
      initTrayMenuItem(text = "Screen On", checked = isScreenOnEnabled, cb = screen_cb),
      initTrayMenuItem(text = "-"),
      initTrayMenuItem(text = "Quit", cb = quit_cb)
    ]
  )
  doAssert trayInit(addr tray) == 0

  let app = App(wSystemDpiAware)
  frame = Frame(title="CtrlAltTab", size=(400, 300), style = wDefaultFrameStyle or wHideTaskbar)

  # about window
  let textCtrl = TextCtrl(frame, style=wTeRich or wTeMultiLine or wTeReadOnly or wTeCentre)
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
  if isRemapEnabled:
    hkData.hHook = SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)
  if isScreenOnEnabled:
    SetThreadExecutionState(ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED)
  app.mainLoop()

main()

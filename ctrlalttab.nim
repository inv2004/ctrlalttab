import winim/lean
import wNim/[wApp, wFrame]
import wAuto
import os

type
  HotkeyData = object
    hHook: HHOOK
    lastKeyCode: int
    lastModifiers: int
    alttab: bool

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
        sleep(5)  # TODO: to prevent open alt-tab on fast click
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

proc main() =
  let app = App()
  discard Frame()
  SetWindowsHookEx(WH_KEYBOARD_LL, keyProc, GetModuleHandle(nil), 0)
  app.mainLoop()

main()

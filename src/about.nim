import consts

import winim/inc/shellapi
import wNim/[wApp, wTextCtrl, wCheckBox]
import wAuto

import std/with
import std/os

proc autorunCheckBox(textCtrl: wTextCtrl) =
  let checkbox = CheckBox(textCtrl, label="Autorun")
  let exePath = getAppFilename()
  let regVal = regRead(REG_AUTORUN_PATH, REG_AUTORUN_VAL)
  let isEnabled = regVal.kind == rkRegSz and regVal.data == exePath
  checkbox.setValue(isEnabled)
  checkbox.wEvent_CheckBox do ():
    if checkbox.getValue():
      regWrite(REG_AUTORUN_PATH, REG_AUTORUN_VAL, getAppFilename())
    else:
      regDelete(REG_AUTORUN_PATH, REG_AUTORUN_VAL)

proc about*(frame: wWindow) =
  let textCtrl = TextCtrl(frame, style=wTeRich or wTeMultiLine or wTeReadOnly or wTeCentre)
  with textCtrl:
    setStyle(lineSpacing=1.5)
    writeText("\n")
    autorunCheckBox()
    writeText("CtrlAltTab shortcut remapper\n")
    writeLink(HOMEPAGE_URL, HOMEPAGE_URL)
    writeText("\n")
    writeText("Author\n")
    writeLink(AUTHOR_URL, AUTHOR_URL)
    writeText("\n\n")
    writeText("Alt-Tab => Ctrl-Tab\n")
    writeText("Ctrl-PgUp|Down => Ctrl-[|]\n")
    writeText("Caps => Win-Space\n")
    writeText("Back/Forward (Lenovo PgUp/Down) => PgUp|Down\n")
    writeText("Win+Shift+F23 (Lenovo AI key) => Home\n")
    writeText("\n")
    resetStyle()

  textCtrl.wEvent_TextLink do (event: wEvent):
    if event.mouseEvent == wEvent_LeftUp:
      ShellExecute(0, "open", textctrl.range(event.start..<event.end), nil, nil, 5)

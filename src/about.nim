import winim/inc/shellapi
import wNim/[wApp, wTextCtrl]

import std/with

const url = "https://github.com/inv2004/ctrlalttab"
const authorUrl = "https://github.com/inv2004"

proc about*(frame: wWindow) =
  let textCtrl = TextCtrl(frame, style=wTeRich or wTeMultiLine or wTeReadOnly or wTeCentre)
  with textCtrl:
    setStyle(lineSpacing=1.5)
    writeText("\n")
    writeText("CtrlAltTab shortcut remapper\n")
    writeLink(url, url)
    writeText("\n")
    writeText("Author\n")
    writeLink(authorUrl, authorUrl)
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

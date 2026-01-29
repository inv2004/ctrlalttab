# Package

version       = "0.1.0"
author        = "inv2004"
description   = "Remap some windows shortcuts. Simple replacement for powertoys keyboard manager"
license       = "Apache-2.0"
srcDir        = "src"
bin           = @["ctrlalttab"]


# Dependencies

requires "nim == 2.0.8"
requires "wAuto"
requires "libtray"

after build:
  exec "rcedit.exe ctrlalttab.exe --set-icon icon.ico"
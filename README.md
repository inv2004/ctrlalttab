# ctrlalttab

Remap some windows shortcuts. Simple replacement for powertoys keyboard manager

- triggers alt-tab for ctrl-tab, supports multi tab switch
- ctrl+\[ to ctrl+pgup, ctrl+\] to ctrl+pgdown
- caps to Alt+Shift # Language switch
- win+shift+f23 to home # lenovo AI key
- screen on functionality
- tray menu

## Simple keys remap

I prefer to remap single keys via `Scancode Map`, that is why I use with with the following regedit:

```
alt <=> ctrl
rctrl => end
ralt => home
rmenu => home
home => print screen (maybe will remove)
```

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" /v "Scancode Map" /t REG_BINARY /d 0000000000000000070000001D00380038001D004FE01DE047E038E047E05DE037E047E000000000
```

## requirements
- Windows
- Nim 2.0.8

## build
```
nimble install wAuto libtray
nim c -d:release -d:strip --opt:size --app:gui ctrlalttab.nim
```

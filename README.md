# ctrlalttab

Remap some windows shortcuts. Simple replacement for powertoys keyboard manager

- triggers alt-tab for ctrl-tab, supports multi tab switch
- ctrl+\[ to pgup, ctrl+\] to pgdown
- caps to Alt+Shift # Language switch
- win+shift+f23 to home # lenovo AI key
- screen on functionality
- tray menu

## Simple keys remap

I prefer to remap single keys via `Scancode Map`, that is why I use with with the following regedit:
`Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Scancode Map`
```
00 00 00 00 00 00 00 00
07 00 00 00 1D 00 38 00
38 00 1D 00 4F E0 1D E0
47 E0 38 E0 47 E0 5D E0
37 E0 47 E0 00 00 00 00
```

sharpkeys do the same thing, and also does not support shortcuts remap

## requirements
- Windows
- Nim 2.0.8

## build
```
nimble install wAuto libtray
nim c -d:release -d:strip --opt:size --app:gui ctrlalttab.nim
```

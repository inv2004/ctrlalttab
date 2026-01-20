# ctrlalttab
triggers alt-tab for ctrl-tab
supports multi tab scroll

## requirements
- Windows
- Nim 1.6.20
- nimble install wAuto

## build
`nim c -d:release ctrlalttab.nim`

I use with with the following keys regedit:
"Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Scancode Map"
```
00 00 00 00 00 00 00 00
07 00 00 00 1D 00 38 00
38 00 1D 00 4F E0 1D E0
47 E0 38 E0 47 E0 5D E0
37 E0 47 E0 00 00 00 00
```

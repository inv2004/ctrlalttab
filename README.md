# ctrlalttab

![image](.github/images/screen.png)

Remaps some windows _shortcuts_. Simple replacement for powertoys keyboard manager

The tool remaps _only_ shortcuts because single keys remap is much better via `Scancode Map` or SharpKeys

- `alt-tab` for ctrl-tab, supports multi tab switch. Could be useful is you `swap ctrl<=>alt`
- `ctrl+\[` / `]`, to ctrl+pgup / down
- `caps` to Alt+Shift # Language switch
- `win+shift+f23` to home # lenovo AI key. Good is right ctrl is mapped to `end`
- `screen-on` functionality
- tray menu
- saves settings in registry `HKEY_CURRENT_USER\SOFTWARE\CtrlAltDel`
- autorun switch

## preparation

I prefer to remap single keys via windows registry value `Scancode Map`, that is why I use ctrlalttab with the following regedit:

```
alt <=> ctrl
rctrl => end
ralt => home
rmenu => home
home => print screen (maybe will remove)
```

amend it for your own needs or use sharpkeys for the same needs

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" /v "Scancode Map" /t REG_BINARY /d 0000000000000000070000001D00380038001D004FE01DE047E038E047E05DE037E047E000000000
```

# final layout
![image](.github/images/layout.png)

## requirements
- Windows
- Nim 2.0.8

## build
```
nimble build -d:release -d:strip --opt:size --app:gui
```

or using zig cc (to avoid win defender)
```
nimble build --cc:clang --clang.exe="zigcc.cmd" --clang.linkerexe="zigcc.cmd" -d:release -d:strip --opt:size --app:gui
```

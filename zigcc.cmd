@echo off
zig cc %* -Wl,--subsystem,windows

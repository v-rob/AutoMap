:: AutoMap: Copyright 2021 Vincent Robinson under the MIT license. See `license.txt` for more info.

@echo off
lua\lua54.exe -W src\init.lua fast %1
if %ERRORLEVEL% NEQ 0 pause

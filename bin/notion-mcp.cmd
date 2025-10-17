@echo off
setlocal

set "NODE_EXE=node"
where "%NODE_EXE%" >nul 2>&1
if errorlevel 1 (
  if exist "C:\Program Files\nodejs\node.exe" set "NODE_EXE=C:\Program Files\nodejs\node.exe"
)

"%NODE_EXE%" "%~dp0\..\dist\server.js"

endlocal


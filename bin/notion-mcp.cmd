@echo off
setlocal

rem Robust Node resolver for Windows
set "NODE_EXE="
where node >nul 2>nul && set "NODE_EXE=node"
if not defined NODE_EXE if defined NVM_SYMLINK if exist "%NVM_SYMLINK%\node.exe" set "NODE_EXE=%NVM_SYMLINK%\node.exe"
if not defined NODE_EXE if exist "%LOCALAPPDATA%\Programs\nodejs\node.exe" set "NODE_EXE=%LOCALAPPDATA%\Programs\nodejs\node.exe"
if not defined NODE_EXE if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if not defined NODE_EXE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles(x86)%\nodejs\node.exe"
if not defined NODE_EXE if exist "C:\ProgramData\chocolatey\bin\node.exe" set "NODE_EXE=C:\ProgramData\chocolatey\bin\node.exe"

if not defined NODE_EXE (
  echo ERROR: Node.js executable not found on PATH or common locations.
  echo Please install Node.js 20+ or add node to PATH.
  exit /b 1
)

"%NODE_EXE%" --no-warnings "%~dp0\..\dist\extension.cjs"

endlocal

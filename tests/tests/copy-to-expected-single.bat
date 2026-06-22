@echo off

set /P confirm=Replace production files with recent output files [y/n]? 

if [%confirm%] neq [y] exit 0

set BASEDIR=%~dp0

(
echo .failed
echo .bak
echo .log
)>"%TEMP%\ignore.txt"

set POST=%~n1

dir "%BASEDIR%\output\%POST%" /AD /S /B >%TEMP%\FOUND_DIRS.txt

if %ERRORLEVEL% neq 0 (
  type %TEMP%\FOUND_DIRS.txt
  pause
  exit 1
)

@for /f "delims=^" %%i in (%TEMP%\FOUND_DIRS.txt) do (
  set OUTPUT_DIR=%%i
  goto :FOUND
)
:FOUND

REM Optional, clear existing expected files
REM This is not desired by default, it can potentially happen that test files are only generated in a single unit
REM and the code below would delete the other units expected output
set EXPECTED_DIR=%OUTPUT_DIR:\output\=\expected\%
if EXIST "%EXPECTED_DIR%" (
  REM del "%EXPECTED_DIR%"\*.* >nul /q /s 
)

xcopy "%OUTPUT_DIR%" "%EXPECTED_DIR%" /EXCLUDE:%TEMP%\ignore.txt /E /Y

REM Pause only if bat was not called from VSCODE as a task
IF "%2" NEQ "nopause" (
  pause
)

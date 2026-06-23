@echo off
setlocal ENABLEDELAYEDEXPANSION

rem The first argument is the post file name

set BASEDIR=%~dp0
if "%BASEDIR:~-1%"=="\" set BASEDIR=%BASEDIR:~0,-1%

set POST=%~n1
set POST_DIR=%~dp1

if NOT EXIST "%POST_DIR%%POST%.cps" (
  echo No such post: %POST%
  pause
  exit /b 1
)

rem Clear existing output files
set OUTPUT_FOLDER=%BASEDIR%\output
if EXIST "%OUTPUT_FOLDER%" (
  del "%OUTPUT_FOLDER%"\*.* >nul /q /s
)

rem Uncomment line below to add extra flags

set POST_TESTING_SETTINGS=%APPDATA%\PostTestingSystem\settings.json

if EXIST "%POST_TESTING_SETTINGS%" (
  set EXTRA_FLAGS0=--settings="%POST_TESTING_SETTINGS%"
)

if NOT EXIST "%POST_TESTING_SETTINGS%" (
  if EXIST "%BASEDIR%\settings.json" (
    set EXTRA_FLAGS0=--settings="%BASEDIR%\settings.json"
  )
)

if "%2" == "stopOnFailure" (
  set EXTRA_FLAGS="--%2"
)

if "%3" EQU "MM" set initialUnit="--initialUnit=%3"
if "%3" EQU "IN" set initialUnit="--initialUnit=%3"

rem If post engine not set use the default one
rem from the Artifactory

set POST_ENGINE=%BASEDIR%\..\jenkins\packages\post\vc142\x64\post.exe

rem Skip version check if post.exe exists

pushd "%BASEDIR%"

node .\run-tests.js --postEngine="%POST_ENGINE%" --color %EXTRA_FLAGS0% %EXTRA_FLAGS% --post="%~f1" .\test_cases --dataDir="." --ignore="ignore_single.json" --problemsOnly --parallel=1 %initialUnit%
set TEST_EXIT=%errorlevel%

popd

rem Pause only if bat was not called from VSCODE as a task
IF "%2" NEQ "nopause" (
  pause
)

rem needed for git hooks pre-commit
IF %TEST_EXIT% NEQ 0 (
  goto failed
)

goto end

:failed
  endlocal
  Echo Error detected, see error message above. The exit code is %errorlevel%
  exit /b 1

:end
exit /b 0

@echo off

rem The first argument is optional post engine path.

rem Uncomment line below to add extra flags
set EXTRA_FLAGS0=--externalDiff=3

set BASEDIR=%~dp0

rem If post engine not set use the default one
rem from the Artifactory

rem Clear existing output files
set OUTPUT_FOLDER=%BASEDIR%\output
if EXIST "%OUTPUT_FOLDER%" (
  del "%OUTPUT_FOLDER%"\*.* >nul /q /s
)

set POST_ENGINE=%BASEDIR%..\jenkins\packages\post\vc142\x64\post.exe

if [%1] EQU [] (
  if NOT EXIST "%POST_ENGINE%" (
    pushd %BASEDIR%\..\jenkins
    python packages.py update .
    popd
  )
) else (
  rem User defined post engine
  set POST_ENGINE=%1
)
if %errorlevel% NEQ 0 (
  goto failed
)

pushd %BASEDIR%

node .\run-tests.js --postEngine=%POST_ENGINE% --color %EXTRA_FLAGS0% %EXTRA_FLAGS% .\test_cases  --postDir=".." --dataDir="." --ignore="ignore_all.json;ignore_single.json"  --stopOnFailure

popd

goto end

:failed
  Echo Error detected, see error message above. The exit code is %errorlevel%
  exit 1

:end

pause
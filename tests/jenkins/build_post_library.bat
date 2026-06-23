@echo off

setlocal

set SCRIPTDIR=%~dp0

rem run packages.py to update third parties
pushd %SCRIPTDIR%
  py -3 -E packages.py update .
popd

echo Build post library...
echo.

set DST=%1
set REF=%2

set PATH=%SCRIPTDIR%packages\post\vc142\x64;%PATH%
if %ERRORLEVEL% neq 0 (
  echo Error: Failed to run post processor.
  exit /b 1
)

if "%REF%"=="" (
  py -3 %SCRIPTDIR%build_post_library.py --destination %DST%
) else (
  py -3 %SCRIPTDIR%build_post_library.py --destination %DST% --reference %REF%
)

if %ERRORLEVEL% neq 0 (
  echo Error: Failed to build post library.
  exit /b 1
)

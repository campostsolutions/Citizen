@echo off
setlocal

@REM TODO: incorporate this script into Jenkins CI for post-library
@REM TODO: add fusion streamer path to variable defined below, see https://jira.autodesk.com/browse/CAM-24561

@REM Regenerates all required CNC files defined in the post library tests, then runs
@REM the post library tests afterwards.

if {%WORKSPACE%}=={} set WORKSPACE=%~dp0..\..\..\post-library
set POST_LIBRARY_PATH=%WORKSPACE%
if not defined _NEUTRON_3P set _NEUTRON_3P=%WORKSPACE%\3P

@REM TODO: set fusion streamer path here
set FUSIONSTREAMEREXEPATH=%WORKSPACE%/Lib64/Release_Build/Release/Fusion360.exe

if not exist %FUSIONSTREAMEREXEPATH%  (
  @echo Fusion streamer executable is missing!
  exit /b 1
)

@echo Running post library tests

%FUSIONSTREAMEREXEPATH% -execute "APIScripts.run /closeAfterDone \"%POST_LIBRARY_PATH%\tests\regenerate-cnc.py\""

@REM Just skip cnc regeneration if error, and reset error level with echo
IF %ERRORLEVEL% GEQ 1 echo "Warning: errors during cnc generation detected"

set POST_ENGINE_PATH=%POST_LIBRARY_PATH%\jenkins\packages\post\vc142\x64\post.exe
"%POST_LIBRARY_PATH%\jenkins\run_tests.bat %POST_ENGINE_PATH%"
IF %ERRORLEVEL% GEQ 1 (
    @echo Errors encountered during post library tests.
    exit /b 1
)

@echo Finished post library tests

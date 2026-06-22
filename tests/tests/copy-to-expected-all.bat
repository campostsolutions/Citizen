@echo off

set /P confirm=Replace ALL production files with recent output files [y/n]? 

if [%confirm%] neq [y] exit 0

set BASEDIR=%~dp0

(
echo .failed
echo .bak
echo .log
)>"%TEMP%\ignore.txt"

pushd %BASEDIR%

if EXIST ".\expected" (
  del .\expected\* >nul /q /s
)
xcopy .\output .\expected /EXCLUDE:%TEMP%\ignore.txt /E /Y

popd
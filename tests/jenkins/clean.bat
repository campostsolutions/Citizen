@echo off

setlocal

set SCRIPTDIR=%~dp0

git -C "%SCRIPTDIR%.." clean -fdx

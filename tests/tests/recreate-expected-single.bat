@echo off

rem The first argument is the post file name

set EXTRA_FLAGS=--fit --problemsOnly

call %~dp0\run-single.bat %1
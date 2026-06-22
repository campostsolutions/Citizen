@echo off

rem The first argument is optional post engine path.

set EXTRA_FLAGS=--fit --problemsOnly

call %~dp0\run-all.bat %1
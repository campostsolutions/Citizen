@echo off
REM Test runner for Citizen posts
REM Usage: run-citizen-tests.bat [post_name]
REM Example: run-citizen-tests.bat "Citizen L320-VIII.cps"

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"

REM Set up paths
set TESTS_DIR=%CD%
set POSTS_DIR=..\..\Current Release\posts
set NODEJS_RUNNER=%TESTS_DIR%\run-tests.js

if NOT EXIST "%POSTS_DIR%" (
  echo Error: Posts directory not found: %POSTS_DIR%
  pause
  exit 1
)

if NOT EXIST "%NODEJS_RUNNER%" (
  echo Error: Test runner not found: %NODEJS_RUNNER%
  echo Please run this from the tests/tests directory
  pause
  exit 1
)

REM Check if specific post was provided
if "%~1"=="" (
  echo Usage: %0 [post_name]
  echo.
  echo Available posts:
  dir "%POSTS_DIR%\*.cps" /b
  echo.
  echo Example: %0 "Citizen L320-VIII.cps"
  echo Example: %0 "Citizen L12-VII"
  pause
  exit 0
)

REM Get post name and normalize it
set POST_NAME=%~1
if NOT "%POST_NAME:~-4%"==".cps" (
  set POST_NAME=%POST_NAME%.cps
)

REM Verify post exists
if NOT EXIST "%POSTS_DIR%\%POST_NAME%" (
  echo Error: Post not found: %POSTS_DIR%\%POST_NAME%
  pause
  exit 1
)

echo.
echo ================================================================
echo Testing Citizen Post: %POST_NAME%
echo ================================================================
echo.

REM Run the test
call "%TESTS_DIR%\run-single.bat" "%POSTS_DIR%\%POST_NAME%"

REM Check results
if exist "%TESTS_DIR%\output" (
  echo.
  echo Output files created in: %TESTS_DIR%\output
  if exist "%TESTS_DIR%\output\*.log" (
    echo.
    echo View logs:
    dir "%TESTS_DIR%\output\*.log" /b
  )
)

pause

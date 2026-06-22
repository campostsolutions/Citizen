@echo off
REM Simple test runner for Citizen posts
REM Shows available posts and runs tests
REM Usage: run-citizen-post.bat [post_name]

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"

REM Colors for output (using basic echo)
set "GREEN=[32m"
set "RED=[31m"
set "YELLOW=[33m"
set "CYAN=[36m"
set "RESET=[0m"

REM Set up paths
set TESTS_DIR=%CD%
set POSTS_DIR=..\..\Current Release\posts

if NOT EXIST "%POSTS_DIR%" (
  echo Error: Posts directory not found: %POSTS_DIR%
  pause
  exit 1
)

echo.
echo ================================================================
echo Citizen Post Processor Test Runner
echo ================================================================
echo.

REM If no argument provided, show help
if "%~1"=="" (
  echo Usage: %0 [post_name]
  echo.
  echo Available Citizen Posts:
  echo.
  dir "%POSTS_DIR%\Citizen*.cps" /b 2>nul | findstr /r ".*"
  if !ERRORLEVEL! neq 0 (
    echo   (No Citizen posts found)
  )
  echo.
  echo Available Miyano Posts:
  echo.
  dir "%POSTS_DIR%\Miyano*.cps" /b 2>nul | findstr /r ".*"
  if !ERRORLEVEL! neq 0 (
    echo   (No Miyano posts found)
  )
  echo.
  echo Examples:
  echo   %0 "Citizen L320-VIII"
  echo   %0 "Miyano BNE-MYY"
  echo   %0 "Citizen L12-VII.cps"
  echo.
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
  echo Error: Post not found: %POST_NAME%
  echo.
  echo Available posts in %POSTS_DIR%:
  dir "%POSTS_DIR%\*.cps" /b
  echo.
  pause
  exit 1
)

echo Testing: %POST_NAME%
echo.

REM Clear output directory
if exist "%TESTS_DIR%\output" (
  del "%TESTS_DIR%\output\*.*" /q 2>nul
)

REM Run test using the original run-single.bat
call "%TESTS_DIR%\run-single.bat" "%POSTS_DIR%\%POST_NAME%"

REM Check results
set RESULT=%ERRORLEVEL%

echo.
echo ================================================================
if %RESULT% equ 0 (
  echo Test Completed
) else (
  echo Test had errors (exit code: %RESULT%)
)
echo ================================================================
echo.

REM Show output summary
if exist "%TESTS_DIR%\output" (
  set /a NC_COUNT=0
  set /a LOG_COUNT=0
  
  for /f %%f in ('dir /b "%TESTS_DIR%\output\*.nc" 2^>nul ^| find /c /v ""') do set NC_COUNT=%%f
  for /f %%f in ('dir /b "%TESTS_DIR%\output\*.log" 2^>nul ^| find /c /v ""') do set LOG_COUNT=%%f
  
  echo Output files generated:
  echo   NC files:  !NC_COUNT!
  echo   Log files: !LOG_COUNT!
  echo.
  echo Output directory: %TESTS_DIR%\output
)

pause
exit %RESULT%

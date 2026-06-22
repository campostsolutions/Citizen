@echo off
REM Test runner for ALL Citizen posts
REM Tests each Citizen post against the test cases

setlocal ENABLEDELAYEDEXPANSION

cd /d "%~dp0"

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
echo Testing ALL Citizen Posts
echo ================================================================
echo.

REM List of Citizen posts to test
set POSTS=^
  Citizen L12-VII.cps ^
  Citizen L212-X.cps ^
  Citizen L220-VIII.cps ^
  Citizen L220-X.cps ^
  Citizen L220-XII.cps ^
  Citizen L32-VIII.cps ^
  Citizen L32-X.cps ^
  Citizen L32-XII.cps ^
  Citizen L320-VIII.cps ^
  Citizen L320-X.cps ^
  Citizen L320-XII.cps ^
  Citizen L320-XIIB5.cps ^
  Citizen M532-V.cps ^
  Citizen M532-VIII.cps ^
  Miyano ABX-SYY.cps ^
  Miyano ABX-THY.cps ^
  Miyano ANX.cps ^
  Miyano BNE-MYY.cps

set PASSED=0
set FAILED=0
set SKIPPED=0

REM Test each post
for %%P in (%POSTS%) do (
  if EXIST "%POSTS_DIR%\%%P" (
    echo Testing: %%P
    call "%TESTS_DIR%\run-single.bat" "%POSTS_DIR%\%%P" >nul 2>&1
    if !ERRORLEVEL! equ 0 (
      echo   ✓ PASSED
      set /a PASSED=!PASSED!+1
    ) else (
      echo   ✗ FAILED
      set /a FAILED=!FAILED!+1
    )
  ) else (
    echo Skipping: %%P (not found)
    set /a SKIPPED=!SKIPPED!+1
  )
)

echo.
echo ================================================================
echo Test Summary
echo ================================================================
echo Passed:  !PASSED!
echo Failed:  !FAILED!
echo Skipped: !SKIPPED!
echo Total:   %POSTS%
echo.

if !FAILED! gtr 0 (
  echo Some tests FAILED. Review output directory for details.
  pause
  exit 1
) else (
  echo All tests PASSED!
  pause
  exit 0
)

@echo off
REM Test runner for ALL Citizen posts
REM Tests each Citizen post against the test cases

setlocal ENABLEDELAYEDEXPANSION

set NO_PAUSE=
echo %* | find /I "nopause" >nul
if %ERRORLEVEL% EQU 0 set NO_PAUSE=nopause

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
  "Citizen L12-VII.cps" ^
  "Citizen L212-X.cps" ^
  "Citizen L220-VIII.cps" ^
  "Citizen L220-X.cps" ^
  "Citizen L220-XII.cps" ^
  "Citizen L32-VIII.cps" ^
  "Citizen L32-X.cps" ^
  "Citizen L32-XII.cps" ^
  "Citizen L320-VIII.cps" ^
  "Citizen L320-X.cps" ^
  "Citizen L320-XII.cps" ^
  "Citizen L320-XIIB5.cps" ^
  "Citizen M532-V.cps" ^
  "Citizen M532-VIII.cps" ^
  "Miyano ABX-SYY.cps" ^
  "Miyano ABX-THY.cps" ^
  "Miyano ANX.cps" ^
  "Miyano BNE-MYY.cps"

set PASSED=0
set FAILED=0
set SKIPPED=0
set TOTAL=0

REM Test each post
for %%P in (%POSTS%) do (
  set /a TOTAL=!TOTAL!+1
  if EXIST "%POSTS_DIR%\%%~P" (
    set HAS_JSON=
    for /F "delims=" %%J in ('dir /s /b "%TESTS_DIR%\test_cases\%%~nP.json" 2^>nul') do (
      set HAS_JSON=1
    )

    if defined HAS_JSON (
      echo Testing: %%~P
      call "%TESTS_DIR%\run-single.bat" "%POSTS_DIR%\%%~P" nopause
      set RC=!ERRORLEVEL!
      if !RC! equ 0 (
        echo   [PASSED] %%~P
        set /a PASSED=!PASSED!+1
      ) else (
        echo   [FAILED] %%~P
        set /a FAILED=!FAILED!+1
      )
    ) else (
      echo Skipping: %%~P ^(no matching test case JSON^)
      set /a SKIPPED=!SKIPPED!+1
    )
  ) else (
    echo Skipping: %%~P ^(not found^)
    set /a SKIPPED=!SKIPPED!+1
  )
  echo.
)

echo.
echo ================================================================
echo Test Summary
echo ================================================================
echo Passed:  !PASSED!
echo Failed:  !FAILED!
echo Skipped: !SKIPPED!
echo Total:   !TOTAL!
echo.

if !FAILED! gtr 0 (
  echo Some tests FAILED. Review output directory for details.
  IF "%NO_PAUSE%" NEQ "nopause" (pause)
  exit /b 1
) else (
  echo All tests PASSED!
  IF "%NO_PAUSE%" NEQ "nopause" (pause)
  exit /b 0
)

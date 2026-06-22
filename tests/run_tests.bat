@echo off
REM Quick test runner for Windows
REM Usage: run_tests.bat

cd /d "%~dp0"

echo.
echo ========================================================================
echo CITIZEN POST PROCESSOR BASELINE TEST
echo ========================================================================
echo.

python quick_test.py
set TEST_RESULT=%ERRORLEVEL%

if %TEST_RESULT% equ 0 (
    echo.
    echo ========================================================================
    echo SUCCESS - All outputs match baseline!
    echo ========================================================================
    pause
    exit /b 0
) else (
    echo.
    echo ========================================================================
    echo ATTENTION - Review changes above and decide next action
    echo ========================================================================
    echo.
    echo To accept all changes:
    echo   python baseline_manager.py --accept-all
    echo.
    echo To accept specific file:
    echo   python baseline_manager.py --accept "filename"
    echo.
    pause
    exit /b 1
)

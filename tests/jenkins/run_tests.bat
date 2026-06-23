@echo off

rem Install 64-bit Node.js - see https://nodejs.org/en/download/
rem Install ESLint - see https://eslint.org/docs/user-guide/getting-started
rem   npm install -g eslint
call npm install

setlocal

set SCRIPTDIR=%~dp0
set SOURCEDIR=%SCRIPTDIR%..
set NPM=%USERPROFILE%\AppData\Roaming\npm

rem git log -n 3
rem echo.

set PASSTHROUGH_ARGS=%*

node -v > nul 2>&1
if %errorlevel% neq 0 (
  echo Error: Node.js is not available.
  goto failed
)

set NODE_VERSION=
for /f "tokens=* USEBACKQ" %%F IN (`node -v`) do (
  set NODE_VERSION=%%F
)

if [%NODE_VERSION%] == [] (
  echo Error: Node.js is not available.
  goto failed
)

echo Node.js version %NODE_VERSION%

set NPM_VERSION=
for /f "tokens=* USEBACKQ" %%F IN (`npm -v`) do (
  set NPM_VERSION=%%F
)

if [%NPM_VERSION%] == [] (
  echo Error: NPM is not available.
  goto failed
)

echo NPM version %NPM_VERSION%

set ESLINT_VERSION=
for /f "tokens=* USEBACKQ" %%F in (`node "%SOURCEDIR%\node_modules\eslint\bin\eslint.js" --version`) do (
  set ESLINT_VERSION=%%F
)

if [%ESLINT_VERSION%] == [] (
  echo Error: ESLint is not available.
  goto failed
)

echo ESLint version %ESLINT_VERSION%

echo Checking posts with ESLint...
echo.

rem --config .eslintrc.json
rem --ignore-pattern "*-excel*"
node "%SOURCEDIR%\node_modules\eslint\bin\eslint.js" --config "%SOURCEDIR%\.eslintrc.json" --color --ignore-pattern "*-excel*" **.cps
if %errorlevel% neq 0 (
  echo Error: ESLint detected errors.
  goto failed
)

echo No ESLint errors detected.

rem If onlyEslint is passed, exit without running QA tests
if "%1"=="onlyEslint" (
  exit /b 0
)

rem run packages.py to update third parties
pushd %SCRIPTDIR%
  py -3 -E packages.py update .
popd

rem Run testing system
set POST_ENGINE=%SCRIPTDIR%packages\post\vc142\x64\post.exe
set TESTDIR=%SCRIPTDIR%..\tests

pushd %TESTDIR%

node run-tests.js test_cases --postEngine="%POST_ENGINE%" --problemsOnly --dataDir="." --postDir=".." --ignore="ignore_all.json;ignore_single.json" %PASSTHROUGH_ARGS%

if %errorlevel% neq 0 (
  goto failed
)

popd

endlocal
goto :eof

:failed
  endlocal
  exit /b 1

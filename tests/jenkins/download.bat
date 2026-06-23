@echo off

setlocal

set SCRIPTDIR=%~dp0
set PATH=C:\Program Files\Amazon\AWSCLI;%PATH%
set DIST=%SCRIPTDIR%dist

if not exist "C:\Program Files\Amazon\AWSCLI" (
  echo Error: AWSCLI is not installed.
  goto failed
)

echo Download post library from S3 repository...

if not exist "%DIST%" (
  mkdir "%DIST%"
)

rem Detect Jenkins
if "%BRANCH_NAME%" neq "" (
  rem See https://docs.aws.amazon.com/cli/latest/userguide/cli-environment.html
  if "%AWS_ACCESS_KEY_ID%" == "" (
    echo Error: AWS_ACCESS_KEY_ID is not defined.
    goto failed
  )
  if "%AWS_SECRET_ACCESS_KEY%" == "" (
    echo Error: AWS_SECRET_ACCESS_KEY is not defined.
    goto failed
  )
  if "%BRANCH_NAME%" neq "master" (
    echo Error: Not master branch.
    rem Skip silently instead
    goto done
  )
)

echo Downloading "%DIST%" from s3://cam.autodesk.com-posts
rem --quiet --dryrun
aws s3 sync --quiet s3://cam.autodesk.com-posts "%DIST%"
if %ERRORLEVEL% neq 0 (
  echo Error: Failed to download post library.
  goto failed
)

goto done

:failed
exit /b 1

:done

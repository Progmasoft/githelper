@echo off
rem SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
rem SPDX-License-Identifier: MIT-0
rem
rem Builds githelper from this checkout and installs it on Windows. Options are
rem case-sensitive, except /HELP.
rem
rem   install.cmd                 %USERPROFILE%\.local\bin\githelper.exe, folders
rem                               created; added to the user Path when missing
rem   install.cmd /globalenv      the same, added to the machine Path
rem   install.cmd /path<dir>      <dir>\githelper.exe; <dir> must exist
rem   install.cmd /path:<dir>     the same; /globalenv goes with either
rem   install.cmd /? or /HELP     shows the help
setlocal EnableExtensions DisableDelayedExpansion

rem The folder of this script, taken first: shift moves the script name too.
set "SOURCE=%~dp0"
set "GITHELPER_TARGET="
set "GITHELPER_GIVEN="
set "GITHELPER_SCOPE=User"

:arguments
if "%~1"=="" goto :parsed
set "ARGUMENT=%~1"
if "%ARGUMENT%"=="/?" goto :help
if /I "%ARGUMENT%"=="/HELP" goto :help
if "%ARGUMENT%"=="/globalenv" (
    set "GITHELPER_SCOPE=Machine"
    shift
    goto :arguments
)
if "%ARGUMENT:~0,6%"=="/path:" (
    set "GITHELPER_TARGET=%ARGUMENT:~6%"
    goto :path
)
if "%ARGUMENT:~0,5%"=="/path" (
    set "GITHELPER_TARGET=%ARGUMENT:~5%"
    goto :path
)
echo install.cmd: no option %ARGUMENT%; install.cmd /? shows the options 1>&2
exit /b 2

:path
if not defined GITHELPER_TARGET (
    echo install.cmd: /path needs a directory, as /pathC:\Tools or /path:C:\Tools 1>&2
    exit /b 2
)
set "GITHELPER_GIVEN=1"
shift
goto :arguments

:parsed
if not exist "%SOURCE%go.mod" (
    echo install.cmd: run install.cmd from a checkout of githelper 1>&2
    exit /b 1
)
where go >nul 2>nul || (
    echo install.cmd: Go is needed to build githelper: https://go.dev/dl/ 1>&2
    exit /b 1
)

if defined GITHELPER_GIVEN (
    if not exist "%GITHELPER_TARGET%\" (
        echo install.cmd: %GITHELPER_TARGET% does not exist; create it first, or leave out /path 1>&2
        exit /b 1
    )
) else (
    set "GITHELPER_TARGET=%USERPROFILE%\.local\bin"
)
if not exist "%GITHELPER_TARGET%\" mkdir "%GITHELPER_TARGET%" || exit /b 1

if "%GITHELPER_SCOPE%"=="Machine" (
    net session >nul 2>nul || (
        echo install.cmd: /globalenv changes the machine Path; run install.cmd as an administrator 1>&2
        exit /b 1
    )
)

rem The build goes to a temporary file, so a failed build changes nothing.
pushd "%SOURCE%" || exit /b 1
go build -trimpath -o "%GITHELPER_TARGET%\githelper.exe.new" ./cmd/githelper
set "BUILD=%ERRORLEVEL%"
popd
if not "%BUILD%"=="0" (
    if exist "%GITHELPER_TARGET%\githelper.exe.new" del "%GITHELPER_TARGET%\githelper.exe.new"
    echo install.cmd: the build failed 1>&2
    exit /b 1
)
move /Y "%GITHELPER_TARGET%\githelper.exe.new" "%GITHELPER_TARGET%\githelper.exe" >nul || exit /b 1
echo installed %GITHELPER_TARGET%\githelper.exe

rem The Path of the registry, read and written whole by PowerShell, so a long
rem Path is not cut short as setx cuts it; the folder is added once, at the end.
powershell.exe -NoProfile -NonInteractive -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "$target = $env:GITHELPER_TARGET.TrimEnd('\');" ^
    "$scope = $env:GITHELPER_SCOPE;" ^
    "$path = [Environment]::GetEnvironmentVariable('Path', $scope);" ^
    "$parts = @($path -split ';' | Where-Object { $_ -ne '' });" ^
    "if ($parts | Where-Object { $_.TrimEnd('\') -ieq $target }) { Write-Output ('{0} is in the {1} Path already' -f $target, $scope.ToLower()); exit 0 }" ^
    "[Environment]::SetEnvironmentVariable('Path', (($parts + $target) -join ';'), $scope);" ^
    "Write-Output ('added {0} to the {1} Path; open a new terminal to use it' -f $target, $scope.ToLower())"
if errorlevel 1 (
    echo install.cmd: the Path could not be changed 1>&2
    exit /b 1
)
exit /b 0

:help
echo Usage: install.cmd [/globalenv] [/path^<directory^> ^| /path:^<directory^>] [/? ^| /HELP]
echo.
echo Builds githelper from this checkout with Go and installs it.
echo.
echo   (no option)        Install %%USERPROFILE%%\.local\bin\githelper.exe. The folders
echo                      are created when missing; the folder is added to the user
echo                      Path when the Path does not have it.
echo   /globalenv         Add the folder to the machine Path instead; needs an
echo                      administrator.
echo   /path^<directory^>   Install ^<directory^>\githelper.exe. The directory must
echo   /path:^<directory^>  exist; it is not created. Goes with /globalenv.
echo   /?, /HELP          Show this help.
echo.
echo Options are case-sensitive, except /HELP.
exit /b 0

# SPDX-FileCopyrightText: 2026 Progmasoft <support@progmasoft.com>
# SPDX-License-Identifier: MIT-0

#Requires -Version 7

<#
.SYNOPSIS
Builds githelper from this checkout and installs it on Windows.

.DESCRIPTION
Without -Path, installs %USERPROFILE%\.local\bin\githelper.exe, creating the
folders, and adds the folder to the user Path when the Path does not have it.
With -GlobalEnvironment, the folder goes to the machine Path instead, which
needs an administrator. With -Path, installs <Path>\githelper.exe; the folder
must exist and is not created. Parameters are not case-sensitive.

.PARAMETER Path
The folder to install githelper.exe in. It must exist.

.PARAMETER GlobalEnvironment
Add the folder to the machine Path rather than the user Path.

.PARAMETER Help
Show this help.

.EXAMPLE
./Install-Githelper.ps1

.EXAMPLE
./Install-Githelper.ps1 -Path C:\Tools -GlobalEnvironment
#>

[CmdletBinding()]
param(
    [string] $Path,
    [switch] $GlobalEnvironment,
    [switch] $Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help -Full $PSCommandPath
    exit 0
}

function Exit-WithInstallError([string] $Message) {
    [Console]::Error.WriteLine("Install-Githelper.ps1: $Message")
    exit 1
}

$source = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $source 'go.mod') -PathType Leaf)) {
    Exit-WithInstallError 'run Install-Githelper.ps1 from a checkout of githelper'
}
if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    Exit-WithInstallError 'Go is needed to build githelper: https://go.dev/dl/'
}

if ($PSBoundParameters.ContainsKey('Path')) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Exit-WithInstallError '-Path needs a folder'
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        Exit-WithInstallError "$Path does not exist; create it first, or leave out -Path"
    }
    $target = (Resolve-Path -LiteralPath $Path).ProviderPath
} else {
    $target = Join-Path $env:USERPROFILE '.local\bin'
    New-Item -ItemType Directory -Force -Path $target | Out-Null
}

$scope = if ($GlobalEnvironment) { 'Machine' } else { 'User' }
if ($scope -eq 'Machine') {
    $principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Exit-WithInstallError '-GlobalEnvironment changes the machine Path; run PowerShell as an administrator'
    }
}

# The build goes to a temporary file, so a failed build changes nothing.
$executable = Join-Path $target 'githelper.exe'
$building = "$executable.new"
Push-Location -LiteralPath $source
try {
    & go build -trimpath -o $building ./cmd/githelper
    $built = $LASTEXITCODE -eq 0
} finally {
    Pop-Location
}
if (-not $built) {
    Remove-Item -LiteralPath $building -ErrorAction SilentlyContinue
    Exit-WithInstallError 'the build failed'
}
Move-Item -LiteralPath $building -Destination $executable -Force
Write-Output "installed $executable"

# The Path of the registry, read and written whole; the folder is added once.
$folder = $target.TrimEnd('\')
$current = [Environment]::GetEnvironmentVariable('Path', $scope)
$parts = @(($current ?? '') -split ';' | Where-Object { $_ -ne '' })
if ($parts | Where-Object { $_.TrimEnd('\') -ieq $folder }) {
    Write-Output "$folder is in the $($scope.ToLower()) Path already"
    exit 0
}
[Environment]::SetEnvironmentVariable('Path', (($parts + $folder) -join ';'), $scope)
Write-Output "added $folder to the $($scope.ToLower()) Path; open a new terminal to use it"

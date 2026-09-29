#Requires -Version 5.1
param(
    [ValidateSet('Install', 'Restore', 'Status')]
    [string]$Action = 'Install',
    [switch]$Elevated
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($Action -ne 'Status' -and -not (Test-Administrator)) {
    if ($Elevated) { throw 'Administrator elevation failed.' }
    $launcher = Join-Path $PSScriptRoot 'Install-Plex-DoviMpv.ps1'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Action {1} -Elevated' -f $launcher, $Action
    try {
        $result = Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        exit $result.ExitCode
    } catch {
        Write-Host "Administrator elevation was canceled or failed: $_" -ForegroundColor Red
        [void](Read-Host 'Press Enter to close')
        exit 1
    }
}

$exitCode = 0
try {
    & (Join-Path $PSScriptRoot 'Plex-DoviMpv.ps1') -Action $Action
    Write-Host "`n$Action completed." -ForegroundColor Green
} catch {
    Write-Host "`n$Action failed: $_" -ForegroundColor Red
    $exitCode = 1
}
[void](Read-Host 'Press Enter to close')
exit $exitCode

#Requires -Version 5.1
<#
.SYNOPSIS
  Replace Plex for Windows' mpv DLL and add Dolby Vision Profile 5 color settings.
.DESCRIPTION
  Uses paths discovered on the current PC. No user name or drive letter is built in.
  Install.bat calls this script with -Action Install.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Restore', 'Status')]
    [string]$Action = 'Status',
    [Alias('PlexDirectory')]
    [string]$PlexDir,
    [string]$ConfigDir,
    [Alias('LibmpvPath')]
    [string]$DllPath,
    [ValidatePattern('^[a-fA-F0-9]{64}$')]
    [string]$ExpectedSha256,
    [switch]$Force,
    [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()

# Source: https://github.com/mitzsch/mpv-winbuild/releases/tag/2026-07-25-8c67647b50
$bundleZipHash = 'C2E944780FDAB2EDF50278A2EF30028F7EF06CD061E3B857612E993C004EE7BB'
$bundleDllHash = '1B1D1A527FF6D81915E03F66A4536265D7D5A807117566CF42EF7F7AE8AF5C91'

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-PlexDir {
    if ($PlexDir) { $candidate = $PlexDir }
    else {
        $candidates = @()
        if ($env:ProgramFiles) { $candidates += Join-Path $env:ProgramFiles 'Plex\Plex' }
        if (${env:ProgramFiles(x86)}) {
            $candidates += Join-Path ${env:ProgramFiles(x86)} 'Plex\Plex'
        }
        if ($env:LOCALAPPDATA) { $candidates += Join-Path $env:LOCALAPPDATA 'Plex\Plex' }
        $candidate = $candidates | Where-Object {
            Test-Path -LiteralPath (Join-Path $_ 'libmpv-2.dll')
        } | Select-Object -First 1
    }
    if (-not $candidate) { throw 'Plex was not found. Pass -PlexDir with its install folder.' }
    $resolved = (Resolve-Path -LiteralPath $candidate).Path
    if (-not (Test-Path -LiteralPath (Join-Path $resolved 'libmpv-2.dll'))) {
        throw "libmpv-2.dll was not found in $resolved"
    }
    $resolved
}

function Get-SourceDll([string]$WorkDir) {
    if ($DllPath) {
        $path = (Resolve-Path -LiteralPath $DllPath).Path
        if ((Split-Path -Leaf $path) -ne 'libmpv-2.dll') {
            throw 'The replacement file must be named libmpv-2.dll.'
        }
        $hash = Get-Sha256 $path
        if ($ExpectedSha256 -and $hash -ne $ExpectedSha256.ToUpperInvariant()) {
            throw 'The supplied DLL SHA-256 does not match -ExpectedSha256.'
        }
        return $path
    }
    $zip = Join-Path $WorkDir 'libmpv-2.dll.zip'
    $assets = Join-Path $PSScriptRoot 'assets'
    $parts = @('libmpv-2.dll.zip.001', 'libmpv-2.dll.zip.002')
    $output = [IO.File]::Open($zip, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        foreach ($part in $parts) {
            $partPath = Join-Path $assets $part
            if (-not (Test-Path -LiteralPath $partPath)) { throw "Bundled DLL part not found: $partPath" }
            $inputFile = [IO.File]::OpenRead($partPath)
            try { $inputFile.CopyTo($output) }
            finally { $inputFile.Dispose() }
        }
    } finally { $output.Dispose() }
    if ((Get-Sha256 $zip) -ne $bundleZipHash) { throw 'Bundled ZIP SHA-256 mismatch.' }
    $extracted = Join-Path $WorkDir 'extracted'
    Expand-Archive -LiteralPath $zip -DestinationPath $extracted
    $dlls = @(Get-ChildItem -LiteralPath $extracted -Recurse -File -Filter 'libmpv-2.dll')
    if ($dlls.Count -ne 1) { throw 'The bundled ZIP must contain one libmpv-2.dll.' }
    if ((Get-Sha256 $dlls[0].FullName) -ne $bundleDllHash) {
        throw 'Bundled DLL SHA-256 mismatch.'
    }
    $dlls[0].FullName
}

function Stop-Plex([string]$Exe) {
    $running = @(Get-Process -Name 'Plex' -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and ([IO.Path]::GetFullPath($_.Path) -ieq [IO.Path]::GetFullPath($Exe)) }
        catch { $false }
    })
    foreach ($process in $running) { [void]$process.CloseMainWindow() }
    foreach ($process in $running) {
        if (-not $process.WaitForExit(5000)) { Stop-Process -Id $process.Id -Force }
    }
    return ($running.Count -gt 0)
}

function Start-Plex([string]$Exe) {
    if ($NoRestart) { return }
    if (-not (Test-Path -LiteralPath $Exe)) {
        Write-Warning "Open Plex manually; Plex.exe was not found at $Exe"
        return
    }
    try { Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -Parent $Exe) }
    catch { Write-Warning "Open Plex manually: $_" }
}

function Check-Backups($Record) {
    if (-not (Test-Path -LiteralPath $Record.BackupDll) -or
        (Get-Sha256 $Record.BackupDll) -ne $Record.OriginalDllHash) {
        throw 'The original DLL backup is missing or damaged.'
    }
    if ($Record.HadConfig -and
        (-not (Test-Path -LiteralPath $Record.BackupConfig) -or
         (Get-Sha256 $Record.BackupConfig) -ne $Record.OriginalConfigHash)) {
        throw 'The original mpv.conf backup is missing or damaged.'
    }
}

function Restore-Original($Record) {
    Check-Backups $Record
    Copy-Item -LiteralPath $Record.BackupDll -Destination $Record.TargetDll -Force
    if ($Record.HadConfig) {
        Copy-Item -LiteralPath $Record.BackupConfig -Destination $Record.ConfigFile -Force
    } elseif (Test-Path -LiteralPath $Record.ConfigFile) {
        Remove-Item -LiteralPath $Record.ConfigFile -Force
    }
    if ((Get-Sha256 $Record.TargetDll) -ne $Record.OriginalDllHash) {
        throw 'Restored DLL SHA-256 mismatch.'
    }
    if ($Record.HadConfig -and
        (Get-Sha256 $Record.ConfigFile) -ne $Record.OriginalConfigHash) {
        throw 'Restored mpv.conf SHA-256 mismatch.'
    }
}

function Remove-BackupFiles($Record, [string]$StateFile) {
    Remove-Item -LiteralPath $Record.BackupDll -Force
    if ($Record.HadConfig) { Remove-Item -LiteralPath $Record.BackupConfig -Force }
    Remove-Item -LiteralPath $StateFile -Force
}

if ($env:OS -ne 'Windows_NT') { throw 'This script requires Windows.' }
if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is unavailable.' }
if (-not $ConfigDir) { $ConfigDir = Join-Path $env:LOCALAPPDATA 'Plex' }
$configFile = Join-Path $ConfigDir 'mpv.conf'
$backupConfig = Join-Path $ConfigDir 'mpv.conf.bak'
$stateFile = Join-Path $ConfigDir 'Plex-DoviMpv.state.json'

if ($Action -eq 'Status') {
    if (-not (Test-Path -LiteralPath $stateFile)) {
        Write-Output 'Status: no installation recorded.'
        return
    }
    $record = Get-Content -LiteralPath $stateFile -Raw -Encoding utf8 | ConvertFrom-Json
    $dllMatches = (Test-Path -LiteralPath $record.TargetDll) -and
        ((Get-Sha256 $record.TargetDll) -eq $record.InstalledDllHash)
    $configMatches = (Test-Path -LiteralPath $record.ConfigFile) -and
        ((Get-Sha256 $record.ConfigFile) -eq $record.InstalledConfigHash)
    Write-Output "Status: $($record.Status)"
    Write-Output "Plex folder: $($record.PlexDir)"
    Write-Output "Installed DLL matches: $dllMatches"
    Write-Output "Installed config matches: $configMatches"
    return
}

if ($Action -eq 'Restore') {
    if (-not (Test-Path -LiteralPath $stateFile)) { throw 'No installation record was found.' }
    $record = Get-Content -LiteralPath $stateFile -Raw -Encoding utf8 | ConvertFrom-Json
    Check-Backups $record
    if ($record.Status -eq 'Installed' -and -not $Force) {
        if ((Test-Path -LiteralPath $record.TargetDll) -and
            (Get-Sha256 $record.TargetDll) -ne $record.InstalledDllHash) {
            throw 'Plex DLL changed after installation. Use -Force to overwrite it.'
        }
        if ((Test-Path -LiteralPath $record.ConfigFile) -and
            (Get-Sha256 $record.ConfigFile) -ne $record.InstalledConfigHash) {
            throw 'mpv.conf changed after installation. Use -Force to overwrite it.'
        }
    }
    $exe = Join-Path $record.PlexDir 'Plex.exe'
    [void](Stop-Plex $exe)
    Restore-Original $record
    Remove-BackupFiles $record $stateFile
    Start-Plex $exe
    Write-Output 'Original Plex DLL and mpv.conf restored.'
    return
}

if (Test-Path -LiteralPath $stateFile) {
    throw 'An installation is already recorded. Run -Action Status or -Action Restore.'
}
$resolvedPlexDir = Get-PlexDir
$targetDll = Join-Path $resolvedPlexDir 'libmpv-2.dll'
$backupDll = Join-Path $resolvedPlexDir 'libmpv-2.dll.bak'
$plexExe = Join-Path $resolvedPlexDir 'Plex.exe'
if ((Test-Path -LiteralPath $backupDll) -or (Test-Path -LiteralPath $backupConfig)) {
    throw 'A .bak file already exists. Move or restore that backup before installing.'
}
if (-not (Test-Path -LiteralPath $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}
$workDir = Join-Path ([IO.Path]::GetTempPath()) ('PlexDoviMpv-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDir | Out-Null
try {
    $sourceDll = Get-SourceDll $workDir
    $sourceHash = Get-Sha256 $sourceDll
    if ((Get-Sha256 $targetDll) -eq $sourceHash) {
        throw 'This replacement DLL is already installed; the original cannot be backed up.'
    }
    $hadConfig = Test-Path -LiteralPath $configFile
    try {
        Copy-Item -LiteralPath $targetDll -Destination $backupDll
        if ($hadConfig) { Copy-Item -LiteralPath $configFile -Destination $backupConfig }
        $record = [ordered]@{
            Status = 'Pending'
            PlexDir = $resolvedPlexDir
            TargetDll = $targetDll
            BackupDll = $backupDll
            ConfigFile = $configFile
            BackupConfig = $backupConfig
            HadConfig = $hadConfig
            OriginalDllHash = Get-Sha256 $backupDll
            OriginalConfigHash = if ($hadConfig) { Get-Sha256 $backupConfig } else { $null }
            InstalledDllHash = $sourceHash
            InstalledConfigHash = $null
        }
        $record | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding utf8
    } catch {
        Remove-Item -LiteralPath $backupDll, $backupConfig, $stateFile -Force -ErrorAction SilentlyContinue
        throw
    }
    try {
        [void](Stop-Plex $plexExe)
        Copy-Item -LiteralPath $sourceDll -Destination $targetDll -Force
        if ((Get-Sha256 $targetDll) -ne $sourceHash) { throw 'Installed DLL SHA-256 mismatch.' }
        $settings = "`r`n# BEGIN Plex-DoviMpv`r`nvo=gpu-next`r`ngpu-api=d3d11`r`ntarget-colorspace-hint-mode=target`r`n# END Plex-DoviMpv`r`n"
        $bytes = [Text.Encoding]::ASCII.GetBytes($settings)
        $stream = [IO.File]::Open($configFile, [IO.FileMode]::Append, [IO.FileAccess]::Write)
        try { $stream.Write($bytes, 0, $bytes.Length) }
        finally { $stream.Dispose() }
        $record.InstalledConfigHash = Get-Sha256 $configFile
        $record.Status = 'Installed'
        $record | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding utf8
    } catch {
        $errorMessage = $_
        try {
            [void](Stop-Plex $plexExe)
            Restore-Original $record
            Remove-BackupFiles $record $stateFile
        } catch { throw "Installation failed: $errorMessage. Rollback failed: $_" }
        throw "Installation failed and was rolled back: $errorMessage"
    }
    Start-Plex $plexExe
    Write-Output "Installed DLL: $targetDll"
    Write-Output "Config: $configFile"
    Write-Output "Backups: $backupDll and $(if ($hadConfig) { $backupConfig } else { 'no prior config' })"
} finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedWorkDir = [IO.Path]::GetFullPath($workDir)
    $isOwnFolder = (Split-Path -Leaf $resolvedWorkDir) -match '^PlexDoviMpv-[a-fA-F0-9]{32}$'
    if ($isOwnFolder -and
        $resolvedWorkDir.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedWorkDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

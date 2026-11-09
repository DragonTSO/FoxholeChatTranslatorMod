# Foxhole Chat Translator installer.
# Compatible with Windows PowerShell 5.1 and PowerShell 7.

[CmdletBinding()]
param(
    [string]$FoxholePath,
    [switch]$Dev,
    [switch]$ResetConfig,
    [switch]$SkipAI,
    [switch]$Uninstall,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupRoot = Join-Path $ScriptRoot 'backups'

function Write-Info([string]$Message) { Write-Host ('[INFO] ' + $Message) -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host ('[ OK ] ' + $Message) -ForegroundColor Green }
function Write-Fail([string]$Message) { throw $Message }

function Pause-Installer {
    if (-not $NoPause) { Read-Host 'Nhan Enter de dong trinh cai dat' | Out-Null }
}

function Get-SteamInstallPath {
    $keys = @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )
    foreach ($key in $keys) {
        try {
            $value = (Get-ItemProperty -Path $key -Name SteamPath -ErrorAction Stop).SteamPath
            if ($value -and (Test-Path $value)) { return ($value -replace '/', '\') }
        } catch { }
    }
    return $null
}

function Get-FoxholeCandidates {
    $candidates = New-Object System.Collections.Generic.List[string]
    $steam = Get-SteamInstallPath
    if (-not $steam) { return $candidates }
    $candidates.Add((Join-Path $steam 'steamapps\common\Foxhole'))

    $libraryFile = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $libraryFile) {
        foreach ($line in Get-Content -LiteralPath $libraryFile) {
            if ($line -match '"path"\s+"([^"]+)"') {
                $library = $matches[1] -replace '\\\\', '\'
                $candidates.Add((Join-Path $library 'steamapps\common\Foxhole'))
            }
        }
    }
    return $candidates
}

function Find-FoxholePath {
    if ($FoxholePath) { return $FoxholePath }
    foreach ($candidate in Get-FoxholeCandidates) {
        if (Test-Path (Join-Path $candidate 'War\Binaries\Win64')) { return $candidate }
    }
    Write-Host 'Khong tu dong tim thay Foxhole.' -ForegroundColor Yellow
    Write-Host 'Nhap duong dan thu muc goc Foxhole.'
    return (Read-Host 'Foxhole path')
}

function Get-TargetPath([string]$Root) {
    $warTarget = Join-Path $Root 'War\Binaries\Win64'
    $warExe = Join-Path $warTarget 'War-Win64-Shipping.exe'
    if (Test-Path $warExe) { return $warTarget }

    # Fallback for layouts where the executable name is unavailable.
    if (Test-Path $warTarget) { return $warTarget }

    $engineTarget = Join-Path $Root 'Engine\Binaries\Win64'
    if (Test-Path $engineTarget) { return $engineTarget }
    Write-Fail ('Khong tim thay thu muc DLL cua game: ' + $warTarget + ' hoac ' + $engineTarget)
}

function Assert-GameStopped {
    $process = Get-Process -Name 'FoxholeClient-Win64-Shipping' -ErrorAction SilentlyContinue
    if (-not $process) { $process = Get-Process -Name 'Foxhole' -ErrorAction SilentlyContinue }
    if ($process) { Write-Fail 'Foxhole dang chay. Hay thoat game roi chay lai install.ps1.' }
}

function Get-SourceRoot {
    if ($Dev) {
        $release = Join-Path $ScriptRoot 'build\Release'
        if (-not (Test-Path (Join-Path $release 'version.dll'))) {
            Write-Fail 'Khong tim thay build\Release\version.dll. Hay build project truoc.'
        }
        return $release
    }
    if (-not (Test-Path (Join-Path $ScriptRoot 'version.dll'))) {
        Write-Fail 'Khong tim thay version.dll trong goi ZIP.'
    }
    return $ScriptRoot
}

function Backup-ExistingFiles([string]$Target) {
    $files = @('version.dll', 'chat_translator.dll', 'config.ini', 'term_protection.txt', 'slang_dict.txt', 'tts_readings.txt')
    $existing = @($files | Where-Object { Test-Path (Join-Path $Target $_) })
    if ($existing.Count -eq 0) { return $null }

    New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null
    $backup = Join-Path $BackupRoot ('backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    foreach ($file in $existing) { Copy-Item (Join-Path $Target $file) $backup -Force }
    return $backup
}

function Install-Files([string]$Source, [string]$Target) {
    $required = @('version.dll', 'chat_translator.dll', 'term_protection.txt', 'slang_dict.txt', 'tts_readings.txt', 'config.ini')
    foreach ($file in $required) {
        $sourceFile = Join-Path $Source $file
        if (-not (Test-Path $sourceFile)) { $sourceFile = Join-Path $ScriptRoot $file }
        if (-not (Test-Path $sourceFile)) { Write-Fail ('Thieu file trong goi cai dat: ' + $file) }
    }

    foreach ($file in @('version.dll', 'chat_translator.dll', 'term_protection.txt', 'slang_dict.txt', 'tts_readings.txt')) {
        $sourceFile = Join-Path $Source $file
        if (-not (Test-Path $sourceFile)) { $sourceFile = Join-Path $ScriptRoot $file }
        Copy-Item $sourceFile $Target -Force
    }
    $targetConfig = Join-Path $Target 'config.ini'
    if ($ResetConfig -or -not (Test-Path $targetConfig)) {
        $configSource = Join-Path $Source 'config.ini'
        if (-not (Test-Path $configSource)) { $configSource = Join-Path $ScriptRoot 'config.ini' }
        Copy-Item -LiteralPath $configSource -Destination $targetConfig -Force
        Write-Ok 'Da tao config.ini moi'
    } else { Write-Info 'Giu nguyen config.ini hien tai' }

    $assetSource = Join-Path $Source 'assets'
    if ($Dev) { $assetSource = Join-Path $ScriptRoot 'assets' }
    if (Test-Path $assetSource) {
        $assetTarget = Join-Path $Target 'assets'
        New-Item -ItemType Directory -Force -Path $assetTarget | Out-Null
        Copy-Item (Join-Path $assetSource '*') $assetTarget -Recurse -Force
    }
}

function Remove-Installation([string]$Target) {
    $files = @('version.dll', 'version.dll.disabled', 'chat_translator.dll', 'config.ini', 'term_protection.txt', 'slang_dict.txt', 'tts_readings.txt', 'chat_log.txt', 'loader_log.txt', 'debug_log.txt', 'imgui.ini', 'translation_log.csv')
    foreach ($file in $files) {
        $path = Join-Path $Target $file
        if (Test-Path $path) { Remove-Item $path -Force }
    }
    Write-Info 'Giu lai assets/tools va model da tai de tranh xoa du lieu dung chung.'
}

function Get-InstallTargets([string]$Root) {
    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($relative in @('Engine\Binaries\Win64', 'War\Binaries\Win64')) {
        $path = Join-Path $Root $relative
        if (Test-Path $path) { $targets.Add($path) }
    }
    return $targets
}

try {
    Write-Host 'Foxhole Chat Translator' -ForegroundColor White
    Assert-GameStopped
    $root = Find-FoxholePath
    if (-not $root) { Write-Fail 'Chua nhap duong dan Foxhole.' }
    $target = Get-TargetPath ([System.IO.Path]::GetFullPath($root))

    if ($Uninstall) {
        foreach ($installTarget in Get-InstallTargets ([System.IO.Path]::GetFullPath($root))) {
            Remove-Installation $installTarget
            Write-Ok ('Da go cai dat khoi ' + $installTarget)
        }
    } else {
        $source = Get-SourceRoot
        $backup = Backup-ExistingFiles $target
        if ($backup) { Write-Info ('Da backup file cu tai ' + $backup) }
        Install-Files $source $target
        if (-not $SkipAI) { & (Join-Path $ScriptRoot 'setup-ai.ps1') -Target $target }
        Write-Ok ('Da cai dat vao ' + $target)
        if ($SkipAI) { Write-Host 'AI chua duoc kiem tra: da chon -SkipAI.' }
        Write-Host 'Overlay dung nut VI/JA/... va Tr/Src/--, khong phai hinh radio.'
        Write-Host 'Neu config cu chua dung Vietnamese, chay lai voi -ResetConfig (co backup).'
    }
} catch {
    Write-Host ('Cai dat that bai: ' + $_.Exception.Message) -ForegroundColor Red
    if (-not $NoPause) { Read-Host 'Nhan Enter de dong' | Out-Null }
    exit 1
}

Pause-Installer
exit 0

param([string]$Package = 'D:\Foxhole\ChatTranslator-Vietnamese-build1')
$ErrorActionPreference = 'Stop'
$temp = Join-Path $env:TEMP ('opencode\setup-test-' + [guid]::NewGuid().ToString('N'))
$target = Join-Path $temp 'game\War\Binaries\Win64'
New-Item -ItemType Directory -Path $target -Force | Out-Null
Expand-Archive -LiteralPath ($Package + '.zip') -DestinationPath (Join-Path $temp 'package')
$extracted = Join-Path $temp 'package'
foreach ($dll in @('version.dll','chat_translator.dll')) {
    $build = Join-Path (Split-Path -Parent $PSScriptRoot) "build\Release\$dll"
    if ((Get-FileHash $build).Hash -ne (Get-FileHash (Join-Path $extracted $dll)).Hash) { throw "DLL mismatch: $dll" }
}
$tokens = $null; $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $extracted 'install.ps1'), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { throw ($errors | Out-String) }
Get-ChildItem $extracted -Recurse -File | Where-Object Extension -in '.ps1','.bat','.txt','.ini' | ForEach-Object {
    $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($_.FullName))
    if ($text.Contains([char]0xfffd)) { throw "Invalid text: $($_.Name)" }
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $extracted 'install.ps1') -FoxholePath (Join-Path $temp 'game') -NoPause -SkipAI
if ($LASTEXITCODE) { throw 'Fresh install failed' }
Set-Content (Join-Path $target 'config.ini') "[Translation]`r`nMode=Japanese" -Encoding ASCII
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $extracted 'install.ps1') -FoxholePath (Join-Path $temp 'game') -NoPause -ResetConfig -SkipAI
if ($LASTEXITCODE) { throw 'Upgrade failed' }
if ((Get-Content (Join-Path $target 'config.ini') -Raw) -notmatch 'Mode=Vietnamese') { throw 'Upgrade language incorrect' }
if (-not (Test-Path (Join-Path $target 'assets\radio.png'))) { throw 'Missing assets' }
Write-Output 'PASS: fresh install, upgrade, ZIP DLL hashes, UTF-8 and parser. No real game files changed.'

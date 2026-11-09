[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $root 'FoxholeChatTranslator-Package'
}
$release = Join-Path $root 'build\Release'

if (Test-Path -LiteralPath $OutputDirectory) {
    Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
}

$required = @(
    (Join-Path $release 'version.dll'),
    (Join-Path $release 'chat_translator.dll'),
    (Join-Path $root 'install.ps1'),
    (Join-Path $root 'setup-ai.ps1'),
    (Join-Path $root 'config.ini'),
    (Join-Path $root 'term_protection.txt'),
    (Join-Path $root 'slang_dict.txt'),
    (Join-Path $root 'tts_readings.txt'),
    (Join-Path $root 'setup-vietnamese.bat'),
    (Join-Path $root 'check-dll.bat'),
    (Join-Path $root 'docs\SETUP-VI.txt'),
    (Join-Path $root 'assets')
)

foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing package input: $path" }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory 'diagnostics') -Force | Out-Null

Copy-Item (Join-Path $release 'version.dll') $OutputDirectory
Copy-Item (Join-Path $release 'chat_translator.dll') $OutputDirectory
Copy-Item (Join-Path $root 'install.ps1') $OutputDirectory
Copy-Item (Join-Path $root 'setup-ai.ps1') $OutputDirectory
Copy-Item (Join-Path $root 'setup-vietnamese.bat') $OutputDirectory
Copy-Item (Join-Path $root 'check-dll.bat') $OutputDirectory
Copy-Item (Join-Path $root 'config.ini') $OutputDirectory
Copy-Item (Join-Path $root 'term_protection.txt') $OutputDirectory
Copy-Item (Join-Path $root 'slang_dict.txt') $OutputDirectory
Copy-Item (Join-Path $root 'tts_readings.txt') $OutputDirectory
Copy-Item (Join-Path $root 'docs\SETUP-VI.txt') (Join-Path $OutputDirectory 'HUONG-DAN.txt')
Copy-Item (Join-Path $root 'assets') $OutputDirectory -Recurse

$probe = Join-Path $root 'build\Release\dll_probe.exe'
if (Test-Path -LiteralPath $probe) {
    Copy-Item $probe (Join-Path $OutputDirectory 'diagnostics')
}

$readme = @'
FOXHOLE CHAT TRANSLATOR - GOI CAI DAT

1. Dong Foxhole va Steam.
2. Mo PowerShell tai thu muc nay.
3. Chay:

   powershell -ExecutionPolicy Bypass -File .\install.ps1 -ResetConfig

Installer tu tim Foxhole va uu tien Engine\Binaries\Win64, la thu muc Foxhole dang load VERSION.dll.

Neu muon cai Ollama/model AI:

   powershell -ExecutionPolicy Bypass -File .\setup-ai.ps1 -Target "DUONG_DAN_DLL_CUA_GAME"

Neu game van khong nap mod, chay check-dll.bat va gui dll-check.txt.

Luu y: mod hook DLL vao game va co the bi EAC phat hien. Su dung tu chiu rui ro.
'@
Set-Content -LiteralPath (Join-Path $OutputDirectory 'README-VI.txt') -Value $readme -Encoding UTF8

$hashes = Get-ChildItem -LiteralPath $OutputDirectory -File -Recurse |
    Where-Object { $_.Name -ne 'SHA256SUMS.txt' } |
    Get-FileHash -Algorithm SHA256
$hashes | ForEach-Object {
    '{0}  {1}' -f $_.Hash, $_.Path.Substring($OutputDirectory.Length + 1)
} | Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ASCII

Write-Output "Package created: $OutputDirectory"

param([string]$OutputDirectory = 'D:\Foxhole\ChatTranslator-Vietnamese-build1')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ((Test-Path -LiteralPath $OutputDirectory) -or (Test-Path -LiteralPath ($OutputDirectory + '.zip'))) {
    throw 'Output already exists. Choose a new directory; existing packages are not overwritten.'
}
$files = @('version.dll', 'chat_translator.dll')
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $root "build\Release\$file"))) { throw "Missing fresh build: $file" }
}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
New-Item -ItemType Directory -Path (Join-Path $OutputDirectory 'diagnostics') | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'build\diagnostics\dll_probe.exe') -Destination (Join-Path $OutputDirectory 'diagnostics')
Copy-Item -LiteralPath (Join-Path $root 'check-dll.bat') -Destination $OutputDirectory
foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $root "build\Release\$file") -Destination $OutputDirectory
}
foreach ($file in @('install.ps1','setup-ai.ps1','setup-vietnamese.bat','config.ini','term_protection.txt','slang_dict.txt','tts_readings.txt')) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $OutputDirectory
}
Copy-Item -LiteralPath (Join-Path $root 'docs\SETUP-VI.txt') -Destination $OutputDirectory
Copy-Item -LiteralPath (Join-Path $root 'assets') -Destination $OutputDirectory -Recurse
$hashes = Get-ChildItem -LiteralPath $OutputDirectory -File -Recurse | Get-FileHash -Algorithm SHA256
$hashes | ForEach-Object { '{0}  {1}' -f $_.Hash, $_.Path.Substring($OutputDirectory.Length + 1) } |
    Set-Content -LiteralPath (Join-Path $OutputDirectory 'SHA256SUMS.txt') -Encoding ASCII
Compress-Archive -Path (Join-Path $OutputDirectory '*') -DestinationPath ($OutputDirectory + '.zip')
Write-Output ($OutputDirectory + '.zip')

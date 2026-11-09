# Download and verify translation AI without launching Foxhole.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Target)
$ErrorActionPreference = 'Stop'
$process = $null
$oldHost = $env:OLLAMA_HOST
$oldModels = $env:OLLAMA_MODELS
$oldOrigins = $env:OLLAMA_ORIGINS
$temp = Join-Path ([IO.Path]::GetTempPath()) ('chattranslator-ai-' + [guid]::NewGuid().ToString('N'))
try {
    if (-not (Test-Path -LiteralPath (Join-Path $Target 'config.ini'))) { throw 'Missing installed config.ini' }
    $section = ''
    $preset = 'Medium'
    $endpoint = 'http://localhost:11435/api/generate'
    foreach ($line in Get-Content -LiteralPath (Join-Path $Target 'config.ini')) {
        if ($line -match '^\s*\[([^]]+)\]') { $section = $matches[1] }
        if ($section -eq 'Translation' -and $line -match '^\s*PerformancePreset\s*=\s*(\S+)\s*$') { $preset = $matches[1] }
        if ($section -eq 'Translation' -and $line -match '^\s*OllamaEndpoint\s*=\s*(\S+)\s*$') { $endpoint = $matches[1] }
    }
    $model = switch ($preset) { 'Low' { 'gemma3:1b' } 'High' { 'gemma3:4b' } default { 'phi4-mini' } }
    $uri = [uri]$endpoint
    if ($uri.Scheme -ne 'http' -or $uri.Host -notin @('localhost','127.0.0.1') -or $uri.AbsolutePath -ne '/api/generate') {
        throw 'Setup supports a local HTTP Ollama endpoint ending in /api/generate only.'
    }
    $port = $uri.Port
    $probe = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $port)
    try { $probe.Start() } finally { $probe.Stop() }
    $ai = Join-Path $Target 'tools\ollama'
    New-Item -ItemType Directory -Path $ai -Force | Out-Null
    New-Item -ItemType Directory -Path $temp | Out-Null
    $exe = Join-Path $ai 'ollama.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Host '[1/4] Download Ollama from official release (may be several GB)...'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $archive = Join-Path $temp 'ollama.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/ollama/ollama/releases/latest/download/ollama-windows-amd64.zip' -OutFile $archive
        $unpacked = Join-Path $temp 'unpacked'
        Expand-Archive -LiteralPath $archive -DestinationPath $unpacked
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked 'ollama.exe'))) { throw 'Downloaded archive has no ollama.exe' }
        # Publish executable last so interrupted copies are retried.
        Get-ChildItem -LiteralPath $unpacked | Where-Object Name -ne 'ollama.exe' | Copy-Item -Destination $ai -Recurse -Force
        Copy-Item -LiteralPath (Join-Path $unpacked 'ollama.exe') -Destination $exe
    }
    Write-Host '[2/4] Start temporary local AI server...'
    $env:OLLAMA_HOST = "127.0.0.1:$port"
    $env:OLLAMA_MODELS = Join-Path $ai 'models'
    $env:OLLAMA_ORIGINS = ''
    New-Item -ItemType Directory -Path $env:OLLAMA_MODELS -Force | Out-Null
    $process = Start-Process -FilePath $exe -ArgumentList 'serve' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $ai 'setup-server.log') -RedirectStandardError (Join-Path $ai 'setup-server-error.log')
    $base = "http://127.0.0.1:$port"
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        if ($process.HasExited) { throw 'AI server exited. Read tools/ollama/setup-server-error.log' }
        try { $null = Invoke-RestMethod "$base/api/version" -TimeoutSec 2; $ready = $true; break } catch { Start-Sleep -Seconds 1 }
    }
    if (-not $ready) { throw 'AI server startup timed out' }
    Write-Host "[3/4] Download model $model. Keep this window open; progress follows."
    & $exe pull $model
    if ($LASTEXITCODE -ne 0) { throw 'Model download failed. Run setup again to retry.' }
    $null = Invoke-RestMethod "$base/api/show" -Method Post -ContentType 'application/json' -Body (@{model=$model} | ConvertTo-Json) -TimeoutSec 30
    Write-Host '[4/4] Test Vietnamese generation (CPU-only machines may take several minutes)...'
    $body = @{model=$model; prompt='Translate into Vietnamese. Output only the translation: We need more supplies.'; stream=$false; options=@{num_predict=64}} | ConvertTo-Json -Depth 4
    $result = Invoke-RestMethod "$base/api/generate" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 600
    if (-not $result.done -or [string]::IsNullOrWhiteSpace($result.response)) { throw 'AI generation returned no completed text' }
    Write-Host $result.response
    Write-Host 'AI READY: model installed and generation verified. This does not verify game DLL loading.' -ForegroundColor Green
} finally {
    if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    $env:OLLAMA_HOST = $oldHost
    $env:OLLAMA_MODELS = $oldModels
    $env:OLLAMA_ORIGINS = $oldOrigins
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

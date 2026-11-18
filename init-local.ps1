$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (!(Test-Path -LiteralPath '.env')) {
    $example = Get-Content -Raw -LiteralPath '.env.example'
    $password = [Guid]::NewGuid().ToString('N')
    $secret = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
    $example = $example -replace '(?m)^POSTGRES_PASSWORD=\r?$', "POSTGRES_PASSWORD=$password"
    $example = $example -replace '(?m)^JWT_SECRET=\r?$', "JWT_SECRET=$secret"
    Set-Content -LiteralPath '.env' -Value $example -Encoding ascii
}

if (!(Get-Command mkcert -ErrorAction SilentlyContinue)) {
    throw 'mkcert is required. Install it, then rerun this script.'
}

New-Item -ItemType Directory -Path certs -Force | Out-Null
& mkcert -install
if ($LASTEXITCODE -ne 0) { throw 'mkcert -install failed' }

& mkcert -cert-file certs/medcontrol.localhost.pem -key-file certs/medcontrol.localhost-key.pem medcontrol.localhost
if ($LASTEXITCODE -ne 0) { throw 'Certificate creation failed' }

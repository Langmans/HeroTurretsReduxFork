param(
    [string]$ModRoot = $(Split-Path $PSScriptRoot -Parent),
    [string]$TargetDir = (Join-Path $env:APPDATA 'Factorio\mods')
)

$ErrorActionPreference = 'Stop'

$infoPath = Join-Path $ModRoot 'info.json'
if (-not (Test-Path $infoPath)) {
    throw "info.json not found in $ModRoot"
}

if (-not (Test-Path $TargetDir)) {
    throw "Target mods folder not found: $TargetDir"
}

$info = Get-Content $infoPath -Raw | ConvertFrom-Json
$zipName = '{0}_{1}.zip' -f $info.name, $info.version
$zipPath = Join-Path $TargetDir $zipName
 $archiveRootName = '{0}_{1}' -f $info.name, $info.version

$tempRoot = Join-Path $env:TEMP ('factorio-pack-' + [guid]::NewGuid().ToString())
$stageDir = Join-Path $tempRoot $archiveRootName

try {
    New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

    Get-ChildItem -Path $ModRoot -Force |
        Where-Object {
            -not $_.Name.StartsWith('.') -and $_.Name -notin @('scripts', 'readme.md')
        } |
        Copy-Item -Destination $stageDir -Recurse -Force

    if (Test-Path $zipPath) {
        Remove-Item $zipPath -Force
    }

    Compress-Archive -Path $stageDir -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Output "Deployed: $zipPath"
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item $tempRoot -Recurse -Force
    }
}

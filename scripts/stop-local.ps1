$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$stateDir = Join-Path $repoRoot '.local-dev'
$composeEnvPath = Join-Path $stateDir 'docker-compose.env'
$flutterPidPath = Join-Path $stateDir 'flutter.pid'

$knownToolPaths = @(
    'C:\Program Files\Docker\Docker\resources\bin',
  'C:\Program Files\Git\cmd',
  (Join-Path $env:USERPROFILE 'tools\flutter\bin')
)

foreach ($toolPath in $knownToolPaths) {
  if ((Test-Path $toolPath) -and -not (($env:Path -split ';') -contains $toolPath)) {
    $env:Path = "$toolPath;$env:Path"
  }
}

function Stop-TrackedProcess {
  param([string]$PidPath)

  if (-not (Test-Path $PidPath)) {
    return
  }

  $pidValue = Get-Content $PidPath -Raw
  if (-not [string]::IsNullOrWhiteSpace($pidValue)) {
    $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
    if ($null -ne $process) {
      Stop-Process -Id $process.Id -Force
    }
  }

  Remove-Item $PidPath -Force
}

function Stop-FlutterWebServerFallback {
  $listenerPids = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique

  foreach ($listenerPid in $listenerPids) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $listenerPid" -ErrorAction SilentlyContinue
    if ($null -eq $process) {
      continue
    }

    if (
      ($process.CommandLine -like '*flutter_tools.snapshot run -d web-server*' -and $process.CommandLine -like '*--web-port 8080*') -or
      ($process.CommandLine -like '*serve-flutter-web.js*' -and $process.CommandLine -like '*8080*')
    ) {
      Stop-Process -Id $listenerPid -Force -ErrorAction SilentlyContinue
    }
  }
}

Stop-TrackedProcess -PidPath $flutterPidPath
Stop-FlutterWebServerFallback

if (Test-Path $composeEnvPath) {
  & docker compose --env-file $composeEnvPath stop app db | Out-Host
}

Write-Host 'Local dev stack stopped.'




$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot "app"
$stateDir = Join-Path $repoRoot ".local-dev"
$composeEnvPath = Join-Path $stateDir "docker-compose.env"
$flutterPidPath = Join-Path $stateDir "flutter.pid"
$flutterLogPath = Join-Path $stateDir "flutter.log"
$flutterLauncherPath = Join-Path $stateDir "start-flutter-web.ps1"
$frontendBuildDir = Join-Path $appDir "build\web"
$frontendStaticServerPath = Join-Path $stateDir "serve-flutter-web.js"
$backendLogPath = Join-Path $stateDir "backend.log"
$backendHealthUrl = "http://127.0.0.1:3000/api/health"
$frontendUrl = "http://127.0.0.1:8080"

$knownToolPaths = @(
    "C:\Program Files\Docker\Docker\resources\bin",
  "C:\Program Files\Git\cmd",
  "$env:USERPROFILE\\tools\\flutter\\bin"
)

foreach ($toolPath in $knownToolPaths) {
  if ((Test-Path $toolPath) -and -not (($env:Path -split ";") -contains $toolPath)) {
    $env:Path = "$toolPath;$env:Path"
  }
}

$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

function Assert-CommandExists {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

function Get-TrackedProcess {
  param([string]$PidPath)

  if (-not (Test-Path $PidPath)) {
    return $null
  }

  $pidValue = Get-Content $PidPath -Raw
  if ([string]::IsNullOrWhiteSpace($pidValue)) {
    Remove-Item $PidPath -Force
    return $null
  }

  $process = Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue
  if ($null -eq $process) {
    Remove-Item $PidPath -Force
    return $null
  }

  return $process
}

function Invoke-NativeOrThrow {
  param(
    [scriptblock]$ScriptBlock,
    [string]$ErrorMessage
  )

  & $ScriptBlock
  if ($LASTEXITCODE -ne 0) {
    throw $ErrorMessage
  }
}

function Test-UrlOnce {
  param([string]$Url)

  try {
    & curl.exe --silent --fail $Url | Out-Null
    return ($LASTEXITCODE -eq 0)
  }
  catch {
    return $false
  }
}

function Wait-ForUrl {
  param(
    [string]$Url,
    [int]$MaxAttempts = 60,
    [int]$DelaySeconds = 2
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    if (Test-UrlOnce -Url $Url) {
      return $true
    }

    Start-Sleep -Seconds $DelaySeconds
  }

  return $false
}

function Wait-ForDockerDaemon {
  param(
    [int]$MaxAttempts = 45,
    [int]$DelaySeconds = 2
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      & docker info | Out-Null
      if ($LASTEXITCODE -eq 0) {
        return $true
      }
    }
    catch {}

    Start-Sleep -Seconds $DelaySeconds
  }

  return $false
}

function Start-DockerDesktopIfAvailable {
  $dockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
  if (-not (Test-Path $dockerDesktopPath)) {
    return
  }

  $existingDockerDesktop = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
  if ($null -ne $existingDockerDesktop) {
    return
  }

  Write-Host "Docker daemon is not ready. Starting Docker Desktop..."
  Start-Process -FilePath $dockerDesktopPath -WindowStyle Minimized | Out-Null
}

function Wait-ForComposeServiceHealthy {
  param(
    [string]$ComposeEnvPath,
    [string]$ServiceName,
    [int]$MaxAttempts = 60,
    [int]$DelaySeconds = 2
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $containerId = (& docker compose --env-file $ComposeEnvPath ps -q $ServiceName).Trim()
    if (-not [string]::IsNullOrWhiteSpace($containerId)) {
      try {
        $healthStatus = (& docker inspect --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" $containerId).Trim()
        if ($healthStatus -eq "healthy" -or $healthStatus -eq "running") {
          return $true
        }
      }
      catch {}
    }

    Start-Sleep -Seconds $DelaySeconds
  }

  return $false
}

function Get-FrontendServerPid {
  $listener = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($null -eq $listener) {
    return $null
  }

  return $listener.OwningProcess
}

function Get-LatestFrontendSourceWriteTime {
  param([string]$AppDir)

  $paths = @(
    (Join-Path $AppDir "lib"),
    (Join-Path $AppDir "web"),
    (Join-Path $AppDir "pubspec.yaml"),
    (Join-Path $AppDir "pubspec.lock")
  )

  $latest = [datetime]::MinValue
  foreach ($path in $paths) {
    if (-not (Test-Path $path)) {
      continue
    }

    $items = Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue
    if ((Get-Item -LiteralPath $path) -is [System.IO.FileInfo]) {
      $items = @((Get-Item -LiteralPath $path))
    }

    foreach ($item in $items) {
      if ($item.LastWriteTime -gt $latest) {
        $latest = $item.LastWriteTime
      }
    }
  }

  return $latest
}

function Stop-ProcessIfRunning {
  param([System.Diagnostics.Process]$Process)

  if ($null -eq $Process -or $Process.HasExited) {
    return
  }

  Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
}

function Write-FrontendStaticServer {
  param([string]$ServerPath)

  Set-Content -Path $ServerPath -Encoding UTF8 -Value @'
const http = require("http");
const fs = require("fs");
const path = require("path");
const net = require("net");

const root = path.resolve(process.argv[2]);
const port = Number(process.argv[3] || 8080);
const apiTarget = "http://127.0.0.1:3000";

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".mjs": "application/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".wasm": "application/wasm",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".woff": "font/woff",
  ".woff2": "font/woff2"
};

function sendFile(response, filePath) {
  fs.readFile(filePath, (error, data) => {
    if (error) {
      response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      response.end("Not found");
      return;
    }

    const ext = path.extname(filePath).toLowerCase();
    response.writeHead(200, {
      "Content-Type": mimeTypes[ext] || "application/octet-stream",
      "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
      "Pragma": "no-cache",
      "Expires": "0",
      "Cross-Origin-Embedder-Policy": "credentialless",
      "Cross-Origin-Opener-Policy": "same-origin"
    });
    response.end(data);
  });
}

function proxyRequest(request, response) {
  const target = new URL(request.url, apiTarget);
  const proxy = http.request(
    target,
    {
      method: request.method,
      headers: {
        ...request.headers,
        host: target.host
      }
    },
    (proxyResponse) => {
      response.writeHead(proxyResponse.statusCode || 502, proxyResponse.headers);
      proxyResponse.pipe(response);
    }
  );

  proxy.on("error", (error) => {
    response.writeHead(502, { "Content-Type": "application/json; charset=utf-8" });
    response.end(JSON.stringify({ error: `Local API proxy failed: ${error.message}` }));
  });

  request.pipe(proxy);
}

function proxyWebSocket(request, socket, head) {
  const target = new URL(request.url, apiTarget);
  const upstream = net.connect(Number(target.port || 80), target.hostname, () => {
    upstream.write(
      `${request.method} ${target.pathname}${target.search} HTTP/${request.httpVersion}\r\n` +
        Object.entries({
          ...request.headers,
          host: target.host
        })
          .map(([key, value]) => `${key}: ${value}`)
          .join("\r\n") +
        "\r\n\r\n"
    );
    if (head.length) {
      upstream.write(head);
    }
    upstream.pipe(socket);
    socket.pipe(upstream);
  });

  upstream.on("error", () => socket.destroy());
  socket.on("error", () => upstream.destroy());
}

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://${request.headers.host || "127.0.0.1"}`);
  let pathname = decodeURIComponent(url.pathname);
  if (
    pathname.startsWith("/api/") ||
    pathname === "/api" ||
    pathname.startsWith("/uploads/") ||
    pathname.startsWith("/socket.io/")
  ) {
    proxyRequest(request, response);
    return;
  }
  if (pathname === "/") {
    pathname = "/index.html";
  }

  const requestedPath = path.normalize(path.join(root, pathname));
  if (!requestedPath.startsWith(root)) {
    response.writeHead(403);
    response.end("Forbidden");
    return;
  }

  fs.stat(requestedPath, (error, stats) => {
    if (!error && stats.isFile()) {
      sendFile(response, requestedPath);
      return;
    }

    sendFile(response, path.join(root, "index.html"));
  });
});

server.on("upgrade", (request, socket, head) => {
  const url = new URL(request.url, `http://${request.headers.host || "127.0.0.1"}`);
  if (url.pathname.startsWith("/socket.io/")) {
    proxyWebSocket(request, socket, head);
    return;
  }
  socket.destroy();
});

server.listen(port, "127.0.0.1", () => {
  console.log(`Drunkard Flutter Web static server running at http://127.0.0.1:${port}`);
  console.log(`Serving ${root}`);
});
'@
}

function Show-ComposeStatus {
  param([string]$ComposeEnvPath)

  Write-Host ""
  Write-Host "Docker compose status:" -ForegroundColor Yellow
  try {
    & docker compose --env-file $ComposeEnvPath ps | Out-Host
  }
  catch {
    Write-Host "Unable to read docker compose status." -ForegroundColor DarkYellow
  }
}

function Show-ContainerLogs {
  param(
    [string]$ContainerName,
    [int]$Tail = 80
  )

  Write-Host ""
  Write-Host ("Recent logs for {0}:" -f $ContainerName) -ForegroundColor Yellow
  try {
    & docker logs --tail $Tail $ContainerName 2>&1 | Out-Host
  }
  catch {
    Write-Host ("Unable to read logs for {0}." -f $ContainerName) -ForegroundColor DarkYellow
  }
}

function Show-FlutterLogTail {
  param(
    [string]$LogPath,
    [int]$Tail = 80
  )

  Write-Host ""
  Write-Host "Recent Flutter log:" -ForegroundColor Yellow

  if (-not (Test-Path $LogPath)) {
    Write-Host "Flutter log file not found yet." -ForegroundColor DarkYellow
    return
  }

  Get-Content $LogPath -Tail $Tail | Out-Host
}

function Write-BackendSnapshot {
  param([string]$LogPath)

  try {
    & docker compose --env-file $composeEnvPath ps *> $LogPath
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "==== drunkard-app-1 logs ===="
    & docker logs --tail 200 drunkard-app-1 *>> $LogPath
    Add-Content -Path $LogPath -Value ""
    Add-Content -Path $LogPath -Value "==== drunkard-db-1 logs ===="
    & docker logs --tail 120 drunkard-db-1 *>> $LogPath
  }
  catch {}
}

function Throw-WithGuidance {
  param(
    [string]$Message,
    [string]$Hint
  )

  if ([string]::IsNullOrWhiteSpace($Hint)) {
    throw $Message
  }

  throw "$Message`r`n`r`n诊断建议：$Hint"
}

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

Assert-CommandExists "docker"
Assert-CommandExists "node"
Assert-CommandExists "npm"
Assert-CommandExists "npx"
Assert-CommandExists "flutter"
Assert-CommandExists "curl.exe"

$existingFlutterProcess = Get-TrackedProcess -PidPath $flutterPidPath
$frontendAlreadyRunning = Test-UrlOnce -Url $frontendUrl

if ($null -eq $existingFlutterProcess -and $frontendAlreadyRunning) {
  $untrackedFrontendPid = Get-FrontendServerPid
  if ($null -ne $untrackedFrontendPid) {
    $existingFlutterProcess = Get-Process -Id $untrackedFrontendPid -ErrorAction SilentlyContinue
    if ($null -ne $existingFlutterProcess) {
      Set-Content -Path $flutterPidPath -Value $existingFlutterProcess.Id
    }
  }
}

if ($null -ne $existingFlutterProcess -and -not $frontendAlreadyRunning) {
  Remove-Item $flutterPidPath -Force
  $existingFlutterProcess = $null
}

if ($null -ne $existingFlutterProcess -and $frontendAlreadyRunning) {
  $latestFrontendWriteTime = Get-LatestFrontendSourceWriteTime -AppDir $appDir
  if ($latestFrontendWriteTime -gt $existingFlutterProcess.StartTime) {
    Write-Host "Frontend source changed after Flutter server started. Restarting Flutter Web server..."
    Stop-ProcessIfRunning -Process $existingFlutterProcess
    Remove-Item $flutterPidPath -Force -ErrorAction SilentlyContinue
    $existingFlutterProcess = $null
    $frontendAlreadyRunning = $false
  }
}

foreach ($path in @($flutterLauncherPath, $backendLogPath)) {
  if (Test-Path $path) {
    Remove-Item $path -Force
  }
}

if ((-not $frontendAlreadyRunning) -and (Test-Path $flutterLogPath)) {
  try {
    Remove-Item $flutterLogPath -Force
  }
  catch {
    Write-Host "Flutter log is currently in use. Keeping existing log file." -ForegroundColor DarkYellow
  }
}

Set-Content -Path $composeEnvPath -Value @(
  "DB_PASSWORD=drunkard_dev_password",
  "JWT_SECRET=dev-secret",
  "WECHAT_APP_ID=local-dev",
  "WECHAT_APP_SECRET=local-dev",
  "SERVER_URL=http://127.0.0.1:3000",
  "FRONTEND_URL=http://127.0.0.1:8080",
  "NODE_ENV=development",
  "INVITE_CODE=0000",
  "ADMIN_PHONE=18800000001",
  "ADMIN_PASSWORD=change_me_admin",
  "CORS_ORIGINS=http://127.0.0.1:8080,http://localhost:8080",
  "PUB_HOSTED_URL=https://pub.flutter-io.cn",
  "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
)

Write-Host "Checking Docker Desktop readiness..."
if (-not (Wait-ForDockerDaemon)) {
  Start-DockerDesktopIfAvailable
}

if (-not (Wait-ForDockerDaemon -MaxAttempts 90 -DelaySeconds 2)) {
  Throw-WithGuidance `
    -Message "Docker daemon is not ready yet." `
    -Hint "请先确认 Docker Desktop 已完全启动，再重新运行 start-local.cmd。"
}

if (-not (Test-Path (Join-Path $appDir ".dart_tool\package_config.json"))) {
  Write-Host "Installing Flutter dependencies..."
  Push-Location $appDir
  try {
    & flutter pub get
  }
  finally {
    Pop-Location
  }
}

Write-Host "Building and starting Docker backend..."
Invoke-NativeOrThrow `
  -ScriptBlock { docker compose --env-file $composeEnvPath up -d db } `
  -ErrorMessage "Docker database startup failed. Please check Docker Desktop and your image mirror settings."

if (-not (Wait-ForComposeServiceHealthy -ComposeEnvPath $composeEnvPath -ServiceName "db" -MaxAttempts 45 -DelaySeconds 2)) {
  Show-ComposeStatus -ComposeEnvPath $composeEnvPath
  Show-ContainerLogs -ContainerName "drunkard-db-1"
  Throw-WithGuidance `
    -Message "Database container did not become healthy in time." `
    -Hint "通常是 Docker Desktop 没准备好、5432 端口冲突，或数据库容器反复重启。"
}

Invoke-NativeOrThrow `
  -ScriptBlock { docker compose --env-file $composeEnvPath up -d --build app } `
  -ErrorMessage "Docker app startup failed. Image build or container create step did not finish."

if (-not (Wait-ForUrl -Url $backendHealthUrl -MaxAttempts 60 -DelaySeconds 2)) {
  Write-BackendSnapshot -LogPath $backendLogPath
  Show-ComposeStatus -ComposeEnvPath $composeEnvPath
  Show-ContainerLogs -ContainerName "drunkard-app-1"
  Throw-WithGuidance `
    -Message ("Backend API did not become ready in time. Snapshot saved to {0}" -f $backendLogPath) `
    -Hint "通常是 Prisma 初始化失败、环境变量错误，或应用容器启动后崩溃。"
}

Write-Host "Backend API is ready."

if ($frontendAlreadyRunning -and $null -ne $existingFlutterProcess) {
  Write-Host "Flutter Web static server is already running. Reusing existing frontend on http://127.0.0.1:8080"
  $flutterProcess = $existingFlutterProcess
}
else {
  if ($null -ne $existingFlutterProcess) {
    Throw-WithGuidance `
      -Message "Flutter process is already running but frontend URL is not responding." `
      -Hint "请先运行 stop-local.cmd 清理残留 Flutter 进程，然后再启动。"
  }

  Write-Host "Building Flutter Web static assets..."
  Push-Location $appDir
  try {
    Invoke-NativeOrThrow `
      -ScriptBlock { flutter build web --pwa-strategy=none --no-wasm-dry-run } `
      -ErrorMessage "Flutter Web build failed. Please check Flutter SDK and pub dependencies."
  }
  finally {
    Pop-Location
  }

  Write-Host "Starting Flutter Web static server on http://127.0.0.1:8080 ..."
  Write-FrontendStaticServer -ServerPath $frontendStaticServerPath
  Set-Content -Path $flutterLauncherPath -Value ('node "{0}" "{1}" 8080 *> "{2}"' -f $frontendStaticServerPath, $frontendBuildDir, $flutterLogPath)

  $flutterProcess = Start-Process `
    -FilePath "powershell.exe" `
    -ArgumentList @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $flutterLauncherPath
    ) `
    -WorkingDirectory $appDir `
    -WindowStyle Hidden `
    -PassThru

  for ($attempt = 1; $attempt -le 90; $attempt++) {
    Start-Sleep -Seconds 2

    if ($flutterProcess.HasExited) {
      Show-FlutterLogTail -LogPath $flutterLogPath
      Throw-WithGuidance `
        -Message ("Flutter Web static server exited early. Check log: {0}" -f $flutterLogPath) `
        -Hint "通常是 8080 端口被占用，或 Node.js 静态服务启动失败。"
    }

    if (Test-UrlOnce -Url $frontendUrl) {
      break
    }

    if ($attempt -eq 90) {
      Show-FlutterLogTail -LogPath $flutterLogPath
      Throw-WithGuidance `
        -Message ("Flutter Web static server did not become ready in time. Check log: {0}" -f $flutterLogPath) `
        -Hint "通常是 8080 端口冲突，或静态服务未能读取 build/web。"
    }
  }
}

$frontendServerPid = Get-FrontendServerPid
if ($null -eq $frontendServerPid) {
  Show-FlutterLogTail -LogPath $flutterLogPath
  Throw-WithGuidance `
    -Message "Flutter Web server started but no listening process was detected on port 8080." `
    -Hint "通常是 Flutter 进程异常退出，或 8080 端口被其他程序占用。"
}

Set-Content -Path $flutterPidPath -Value $frontendServerPid

Write-Host ""
Write-Host "Local dev stack is starting."
Write-Host "Frontend: http://127.0.0.1:8080"
Write-Host "Backend:  http://127.0.0.1:3000/api/health"
Write-Host "Backend logs: docker logs -f drunkard-app-1"
Write-Host ("Flutter log: {0}" -f $flutterLogPath)
Write-Host "Use .\stop-local.cmd to stop the local stack."


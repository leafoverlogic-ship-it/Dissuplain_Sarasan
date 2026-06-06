$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$localRoot = Join-Path $env:LOCALAPPDATA "DissuplainBuilds\dissuplain_app_web_mobile"
$flutterExe = "flutter"
$devModeRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
$devModeEnabled = $false

try {
  $devModeValue = Get-ItemPropertyValue -Path $devModeRegPath -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction Stop
  $devModeEnabled = ($devModeValue -eq 1)
}
catch {
  $devModeEnabled = $false
}

Write-Host "Repo root:  $repoRoot"
Write-Host "Local copy: $localRoot"

if (-not $devModeEnabled) {
  throw "Windows Developer Mode is disabled. Enable it first by running 'start ms-settings:developers' and turning on Developer Mode, then rerun this script."
}

New-Item -ItemType Directory -Path $localRoot -Force | Out-Null

$null = robocopy $repoRoot $localRoot /MIR /XD `
  ".git" `
  ".dart_tool" `
  "build" `
  "windows\flutter\ephemeral" `
  "node_modules" `
  ".firebase"

$robocopyExit = $LASTEXITCODE
if ($robocopyExit -ge 8) {
  throw "robocopy failed with exit code $robocopyExit"
}

Push-Location $localRoot
try {
  if (Test-Path "windows\flutter\ephemeral\.plugin_symlinks") {
    Remove-Item -LiteralPath "windows\flutter\ephemeral\.plugin_symlinks" -Recurse -Force
  }

  & $flutterExe pub get
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed with exit code $LASTEXITCODE"
  }

  & $flutterExe build windows
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build windows failed with exit code $LASTEXITCODE"
  }

  $releaseSource = Join-Path $localRoot "build\windows\x64\runner\Release"
  $releaseTarget = Join-Path $repoRoot "build_local_windows\Release"

  if (Test-Path $releaseTarget) {
    Remove-Item -LiteralPath $releaseTarget -Recurse -Force
  }

  if (Test-Path $releaseSource) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $releaseTarget) -Force | Out-Null
    Copy-Item -Path $releaseSource -Destination $releaseTarget -Recurse -Force
    Write-Host "Copied Windows release output to: $releaseTarget"
  } else {
    Write-Warning "Windows release output was not found at $releaseSource"
  }
}
finally {
  Pop-Location
}

#!/usr/bin/env pwsh

# Stop executing script on any error
$ErrorActionPreference = 'Stop'
# Do not show download progress
$ProgressPreference = 'SilentlyContinue'

function New-TemporaryDirectory {
  $parent = [System.IO.Path]::GetTempPath()
  [string] $name = [System.Guid]::NewGuid()
  New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "     Tsundere Framework Web Installer" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "==> Fetching latest Tsundere release info from GitHub..." -ForegroundColor Yellow

$ApiUrl = "https://api.github.com/repos/TsundereLang/tsundere/releases/latest"
$ReleaseData = try { Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing } catch { throw "Failed to fetch latest release from GitHub." }

$ZipAsset = $ReleaseData.assets | Where-Object { $_.name -match "\.zip$" } | Select-Object -First 1

if (-not $ZipAsset) {
  Write-Warning "No explicit .zip asset found in the latest release. Attempting to use the source code zipball..."
  $ReleaseZipUrl = $ReleaseData.zipball_url
} else {
  $ReleaseZipUrl = $ZipAsset.browser_download_url
}

Write-Host "==> Downloading Tsundere Release..." -ForegroundColor Yellow
Write-Host "URL: $ReleaseZipUrl" -ForegroundColor Gray

$TsundereTempDir = New-TemporaryDirectory
$ZipPath = Join-Path $TsundereTempDir.FullName "TsundereRelease.zip"

Invoke-WebRequest -Uri $ReleaseZipUrl -OutFile $ZipPath -UseBasicParsing

Write-Host "==> Extracting files..." -ForegroundColor Yellow
Expand-Archive -Path $ZipPath -DestinationPath $TsundereTempDir.FullName -Force

# Find the extracted install script 
$InstallerScript = Get-ChildItem -Path $TsundereTempDir.FullName -Recurse -Filter "install-tsundere.ps1" | Select-Object -First 1

if (-not $InstallerScript) {
  # Cleanup before throwing
  Remove-Item $TsundereTempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
  throw "Could not find install-tsundere.ps1 inside the downloaded archive. Are you sure the release zip contains the installer script?"
}

Write-Host "==> Running local Tsundere installer..." -ForegroundColor Yellow
Write-Host ""

try {
  # Execute the extracted installer script in the context of its own folder
  $OriginalLocation = Get-Location
  Set-Location $InstallerScript.DirectoryName
  
  & $InstallerScript.FullName

  Set-Location $OriginalLocation
} catch {
  Write-Host "Installation failed!" -ForegroundColor Red
  throw $_
} finally {
  Write-Host "==> Cleaning up temporary files..." -ForegroundColor Yellow
  Remove-Item $TsundereTempDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Web install process completed." -ForegroundColor Green

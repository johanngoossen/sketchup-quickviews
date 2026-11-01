@echo off
rem Quick Views for SketchUp - Windows installer (single file).
rem Copies the extension into the Plugins folder of every SketchUp version
rem of the current user. No admin rights needed.
setlocal
set "QV_SELF=%~f0"
title Quick Views for SketchUp - Installer
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = [IO.File]::ReadAllText($env:QV_SELF); $s = $t.IndexOf('#PS' + '-START#'); $e = $t.IndexOf('#PAY' + 'LOAD#'); Invoke-Expression $t.Substring($s, $e - $s)"
set "QV_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %QV_RESULT%

#PS-START#
$ErrorActionPreference = 'Stop'
Write-Host ''
Write-Host '  Quick Views @VERSION@ for SketchUp' -ForegroundColor White
Write-Host '  Designed by Johann Goossen - johanngoossen.com'
Write-Host ''

if (Get-Process -Name 'SketchUp' -ErrorAction SilentlyContinue) {
  Write-Host '  SketchUp is running. Please quit SketchUp first, then run this installer again.' -ForegroundColor Yellow
  exit 2
}

$root = Join-Path $env:APPDATA 'SketchUp'
$targets = @(Get-ChildItem -Path $root -Directory -Filter 'SketchUp 20*' -ErrorAction SilentlyContinue |
  ForEach-Object { Join-Path $_.FullName 'SketchUp' } | Where-Object { Test-Path $_ })
if ($targets.Count -eq 0) {
  Write-Host "  No SketchUp folder found in $root." -ForegroundColor Yellow
  Write-Host '  Start SketchUp once, then run this installer again.'
  exit 1
}

$text = [IO.File]::ReadAllText($env:QV_SELF)
$b64 = $text.Substring($text.IndexOf('#PAY' + 'LOAD#') + 9)
$zip = Join-Path $env:TEMP ('jg_quickviews_' + [guid]::NewGuid().ToString('N') + '.zip')
[IO.File]::WriteAllBytes($zip, [Convert]::FromBase64String($b64))
try {
  foreach ($app in $targets) {
    $plugins = Join-Path $app 'Plugins'
    New-Item -ItemType Directory -Force -Path $plugins | Out-Null
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $plugins 'jg_quickviews'), (Join-Path $plugins 'jg_quickviews.rb')
    Expand-Archive -Path $zip -DestinationPath $plugins -Force
    Write-Host "  Installed: $plugins" -ForegroundColor Green
  }
} finally {
  Remove-Item -Force -ErrorAction SilentlyContinue $zip
}
Write-Host ''
Write-Host '  Done. Start SketchUp and open Extensions > Quick Views > Export Scenes ...'
exit 0

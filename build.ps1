# SIMKL Context Menu - Build Script
# Reads id/version from addon.xml automatically. Outputs ZIP to C:\Temp\.
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1
#
# Uses .NET's System.IO.Compression.ZipArchive with forward-slash entry paths on
# purpose — PowerShell's own Compress-Archive uses backslash path separators
# internally on Windows, which breaks Kodi's addon installer on non-Windows
# platforms (same convention as Chronicle_Scraper/Chronicle_Scrobbler's own build.ps1).

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$addonXml    = Join-Path $projectRoot "addon.xml"

# Read id/version from addon.xml -- never hardcoded here.
$xml     = [xml](Get-Content $addonXml -Encoding UTF8)
$version = $xml.addon.version
if (-not $version) {
    Write-Error "Could not read version from addon.xml"
    exit 1
}
$addonFolder = $xml.addon.id
if (-not $addonFolder) {
    Write-Error "Could not read addon id from addon.xml"
    exit 1
}

$buildTemp   = Join-Path $projectRoot "build_temp"
$sourcePath  = Join-Path $buildTemp $addonFolder
$outputDir   = "C:\Temp"
$outputZip   = Join-Path $outputDir "$addonFolder-$version.zip"

Write-Host "======================================"
Write-Host " SIMKL Context Menu v$version - Build"
Write-Host "======================================"

# Step 1: Prepare build_temp
Write-Host ""
Write-Host "--- Preparing build_temp ---"

if (Test-Path $buildTemp) {
    Remove-Item $buildTemp -Recurse -Force
    Write-Host "  Cleaned old build_temp"
}
New-Item -ItemType Directory -Path $sourcePath -Force | Out-Null

# Copy root addon files -- excludes changelog.txt/README.md, which aren't
# needed at runtime (the changelog itself is also embedded in addon.xml's
# own comment block).
$rootFiles = @("addon.xml", "addon.py", "icon.png", "LICENSE.txt")
foreach ($f in $rootFiles) {
    $src = Join-Path $projectRoot $f
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $sourcePath $f)
        Write-Host "  Copied: $f"
    } else {
        Write-Warning "  Missing expected file: $f"
    }
}

# Copy resources/ (excluding __pycache__). context.simkl.test/ (a standalone
# dev/test scaffold with its own addon.xml) is deliberately never copied --
# it's not part of the real shipped addon.
if (Test-Path (Join-Path $projectRoot "resources")) {
    Copy-Item (Join-Path $projectRoot "resources") (Join-Path $sourcePath "resources") -Recurse -Force
    Get-ChildItem -Path $sourcePath -Directory -Recurse -Filter "__pycache__" -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force
    Write-Host "  Copied: resources/ (cleaned __pycache__)"
}
Write-Host "  build_temp ready."

# Step 2: Create ZIP
Write-Host ""
Write-Host "--- Building ZIP ---"

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}
if (Test-Path $outputZip) {
    Remove-Item $outputZip -Force
    Write-Host "  Removed old ZIP"
}

$zip   = [System.IO.Compression.ZipFile]::Open($outputZip, 'Create')
$files = Get-ChildItem -Path $sourcePath -Recurse -File
$count = 0

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($buildTemp.Length + 1)
    $entryName    = $relativePath.Replace("\", "/")
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName, 'Optimal') | Out-Null
    Write-Host "  + $entryName"
    $count++
}

$zip.Dispose()

$zipInfo = Get-Item $outputZip
$zipSize = [math]::Round($zipInfo.Length / 1024, 2)

Write-Host ""
Write-Host "======================================"
Write-Host " BUILD COMPLETE"
Write-Host "======================================"
Write-Host "Version: $version"
Write-Host "Output:  $outputZip"
Write-Host "Files:   $count"
Write-Host "Size:    $zipSize KB"

# Cleanup build_temp
Remove-Item $buildTemp -Recurse -Force
Write-Host "  Cleaned build_temp"

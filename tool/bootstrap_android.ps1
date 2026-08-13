$ErrorActionPreference = 'Stop'

$tools = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\work\tools')
)
$jdk = Join-Path $tools 'jdk17'
$androidSdk = Join-Path $tools 'android-sdk'

$jdkArchiveName = 'OpenJDK17U-jdk_x64_windows_hotspot_17.0.20_8.zip'
$jdkArchive = Join-Path $tools $jdkArchiveName
$jdkUrl = 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20%2B8/OpenJDK17U-jdk_x64_windows_hotspot_17.0.20_8.zip'
$jdkSha256 = '418497be5cf585bdd2203d6486a565d66d3f5e992d5630d45104cb873fab8122'

$commandLineArchiveName = 'commandlinetools-win-15859902_latest.zip'
$commandLineArchive = Join-Path $tools $commandLineArchiveName
$commandLineUrl = "https://dl.google.com/android/repository/$commandLineArchiveName"
$commandLineSha1 = 'b9862337a13e2809a5159dc3a08d058091bd59f6'

New-Item -ItemType Directory -Force -Path $tools | Out-Null

if (-not (Test-Path (Join-Path $jdk 'bin\java.exe'))) {
    if (-not (Test-Path $jdkArchive)) {
        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkArchive
    }
    $actualHash = (Get-FileHash $jdkArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $jdkSha256) {
        throw 'Temurin JDK checksum mismatch.'
    }

    $jdkStaging = Join-Path $tools 'jdk17-staging'
    if (Test-Path $jdkStaging) {
        Remove-Item -LiteralPath $jdkStaging -Recurse -Force
    }
    New-Item -ItemType Directory -Path $jdkStaging | Out-Null
    Expand-Archive -LiteralPath $jdkArchive -DestinationPath $jdkStaging
    $extractedJdk = Get-ChildItem -LiteralPath $jdkStaging -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\java.exe') } |
        Select-Object -First 1
    if ($null -eq $extractedJdk) {
        throw 'Temurin JDK archive did not contain a JDK.'
    }
    Move-Item -LiteralPath $extractedJdk.FullName -Destination $jdk
    Remove-Item -LiteralPath $jdkStaging -Recurse -Force
}

$sdkManager = Join-Path $androidSdk 'cmdline-tools\latest\bin\sdkmanager.bat'
if (-not (Test-Path $sdkManager)) {
    if (-not (Test-Path $commandLineArchive)) {
        Invoke-WebRequest -Uri $commandLineUrl -OutFile $commandLineArchive
    }
    $actualHash = (Get-FileHash $commandLineArchive -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actualHash -ne $commandLineSha1) {
        throw 'Android command-line tools checksum mismatch.'
    }

    $commandLineStaging = Join-Path $tools 'android-command-line-staging'
    if (Test-Path $commandLineStaging) {
        Remove-Item -LiteralPath $commandLineStaging -Recurse -Force
    }
    Expand-Archive -LiteralPath $commandLineArchive -DestinationPath $commandLineStaging
    $latest = Join-Path $androidSdk 'cmdline-tools\latest'
    New-Item -ItemType Directory -Force -Path (Split-Path $latest) | Out-Null
    Move-Item -LiteralPath (Join-Path $commandLineStaging 'cmdline-tools') -Destination $latest
    Remove-Item -LiteralPath $commandLineStaging -Recurse -Force
}

$env:JAVA_HOME = $jdk
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:Path = "$(Join-Path $jdk 'bin');$env:Path"

1..100 | ForEach-Object { 'y' } | & $sdkManager --sdk_root=$androidSdk --licenses | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Android license acceptance failed with exit code $LASTEXITCODE."
}

& $sdkManager --sdk_root=$androidSdk `
    'platform-tools' `
    'platforms;android-36' `
    'build-tools;36.0.0' `
    'ndk;28.2.13676358'
if ($LASTEXITCODE -ne 0) {
    throw "Android SDK installation failed with exit code $LASTEXITCODE."
}

& (Join-Path $jdk 'bin\java.exe') -version
& $sdkManager --sdk_root=$androidSdk --list_installed

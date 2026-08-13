$ErrorActionPreference = 'Stop'

$localBypass = 'localhost,127.0.0.1,::1'
if ([string]::IsNullOrWhiteSpace($env:NO_PROXY)) {
    $env:NO_PROXY = $localBypass
}
elseif ($env:NO_PROXY -notlike '*localhost*') {
    $env:NO_PROXY = "$env:NO_PROXY,$localBypass"
}

$flutter = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\work\tools\flutter\bin\flutter.bat')
)
$localJdk = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\work\tools\jdk17')
)
$localAndroidSdk = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\work\tools\android-sdk')
)
$localGradleHome = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\work\tools\gradle-home')
)
if (-not (Test-Path $flutter)) {
    throw 'Flutter SDK is missing. Run tool/bootstrap_flutter.ps1 first.'
}
if (Test-Path (Join-Path $localJdk 'bin\java.exe')) {
    $env:JAVA_HOME = $localJdk
    $env:Path = "$(Join-Path $localJdk 'bin');$env:Path"
}
if (Test-Path (Join-Path $localAndroidSdk 'cmdline-tools')) {
    $env:ANDROID_HOME = $localAndroidSdk
    $env:ANDROID_SDK_ROOT = $localAndroidSdk
}
$env:GRADLE_USER_HOME = $localGradleHome

$proxyValue = if ($env:HTTPS_PROXY) { $env:HTTPS_PROXY } else { $env:HTTP_PROXY }
if ($proxyValue -and $env:GRADLE_OPTS -notlike '*https.proxyHost*') {
    $proxy = [uri]$proxyValue
    $proxyOptions = @(
        "-Dhttp.proxyHost=$($proxy.Host)"
        "-Dhttp.proxyPort=$($proxy.Port)"
        "-Dhttps.proxyHost=$($proxy.Host)"
        "-Dhttps.proxyPort=$($proxy.Port)"
    ) -join ' '
    $env:GRADLE_OPTS = "$($env:GRADLE_OPTS) $proxyOptions".Trim()
}

& $flutter @args
exit $LASTEXITCODE

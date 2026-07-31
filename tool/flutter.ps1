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
if (-not (Test-Path $flutter)) {
    throw 'Flutter SDK is missing. Run tool/bootstrap_flutter.ps1 first.'
}

& $flutter @args
exit $LASTEXITCODE

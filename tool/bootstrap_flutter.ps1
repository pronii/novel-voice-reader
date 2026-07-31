$ErrorActionPreference = 'Stop'

$version = '3.44.8'
$sha256 = '095c108a08e0377d8a6501fed65aeb288908a070ed3f135e525dc6431c7686e4'
$archive = "flutter_windows_${version}-stable.zip"
$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/$archive"
$tools = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\work\tools'))
$zip = Join-Path $tools $archive
$partialZip = "$zip.partial"
$flutter = Join-Path $tools 'flutter\bin\flutter.bat'

New-Item -ItemType Directory -Force -Path $tools | Out-Null

if (-not (Test-Path $flutter)) {
    if (-not (Test-Path $zip)) {
        Remove-Item -LiteralPath $partialZip -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest -Uri $url -OutFile $partialZip
        Move-Item -LiteralPath $partialZip -Destination $zip
    }

    $actualHash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $sha256) {
        throw "Flutter SDK checksum mismatch. Expected $sha256, got $actualHash."
    }

    Expand-Archive -Path $zip -DestinationPath $tools -Force
}

& $flutter --version

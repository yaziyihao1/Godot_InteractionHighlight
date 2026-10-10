param(
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '..'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$packageRoot = [IO.Path]::GetFullPath($SourceDirectory)
$packageOutput = [IO.Path]::GetFullPath($OutputDirectory)
$packageVersion = (Get-Content -LiteralPath (Join-Path $packageRoot 'VERSION') -Raw).Trim()
if ($packageVersion -ne '0.3.1') { throw 'This release recipe is for version 0.3.1.' }
foreach ($packageRequired in @('project.godot','README.md','README.zh-CN.md','LICENSE','scene/interaction_highlight_demo.tscn','scripts/interaction_highlight_demo.gd','addons/interaction_highlight/highlight_renderer.gd')) {
    if (!(Test-Path -LiteralPath (Join-Path $packageRoot $packageRequired))) { throw "Missing required file: $packageRequired" }
}
New-Item -ItemType Directory -Path $packageOutput -Force | Out-Null
$packageManifestName = 'release_manifest.json'
$packageFiles = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force | Where-Object {
    $packageRelative = [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\','/')
    $packageRelative -ne $packageManifestName -and $packageRelative -notmatch '(^|/)(\.godot|\.git|__pycache__|bin|obj|runs|dist|qa-output)(/|$)' -and $_.Extension -notin @('.log','.pyc','.zip')
} | Sort-Object FullName)
$packageHashes = foreach ($packageFile in $packageFiles) {
    [pscustomobject]@{
        path = [IO.Path]::GetRelativePath($packageRoot, $packageFile.FullName).Replace('\','/')
        size = $packageFile.Length
        sha256 = (Get-FileHash -LiteralPath $packageFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
[pscustomobject]@{version=$packageVersion; license='MIT'; file_count=$packageHashes.Count; files=$packageHashes} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $packageRoot $packageManifestName) -Encoding utf8
$packageZipPath = Join-Path $packageOutput 'GodotInteractionHighlight_v0.3.1.zip'
if (Test-Path -LiteralPath $packageZipPath) {
    $packageZipPath = Join-Path $packageOutput ('GodotInteractionHighlight_v0.3_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.zip')
}
$packageArchive = [IO.Compression.ZipFile]::Open($packageZipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($packageEntry in $packageHashes) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($packageArchive, (Join-Path $packageRoot $packageEntry.path), $packageEntry.path, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($packageArchive, (Join-Path $packageRoot $packageManifestName), $packageManifestName, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
} finally { $packageArchive.Dispose() }
$packageArchive = [IO.Compression.ZipFile]::OpenRead($packageZipPath)
try {
    if ($packageArchive.Entries.Count -ne $packageHashes.Count + 1) { throw 'Archive entry count mismatch.' }
    foreach ($packageEntry in $packageHashes) {
        $packageStored = $packageArchive.GetEntry($packageEntry.path)
        if (!$packageStored -or $packageStored.Length -ne $packageEntry.size) { throw "Archive size mismatch: $($packageEntry.path)" }
        $packageStream = $packageStored.Open()
        try {
            $packageHasher = [Security.Cryptography.SHA256]::Create()
            $packageReadHash = [Convert]::ToHexString($packageHasher.ComputeHash($packageStream)).ToLowerInvariant()
        } finally { $packageStream.Dispose(); $packageHasher.Dispose() }
        if ($packageReadHash -ne $packageEntry.sha256) { throw "Archive hash mismatch: $($packageEntry.path)" }
    }
} finally { $packageArchive.Dispose() }
Write-Output "RELEASE_ZIP_VALIDATED: $packageZipPath"
Get-FileHash -LiteralPath $packageZipPath -Algorithm SHA256

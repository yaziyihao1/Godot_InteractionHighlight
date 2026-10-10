param(
    [string]$ProjectRoot = (Join-Path $PSScriptRoot '..\..'),
    [Parameter(Mandatory=$true)][string]$StageDirectory
)
$ErrorActionPreference = 'Stop'
$qaSourceRoot = [IO.Path]::GetFullPath($ProjectRoot)
$qaStageRoot = [IO.Path]::GetFullPath($StageDirectory)
if (Test-Path -LiteralPath $qaStageRoot) { throw 'Choose a new, nonexistent staging directory.' }
$qaCoreNames = @('highlight_renderer.gd','highlight_style.gd','gpu_state.gd','highlight_effect.gd','depth_proxy.gdshader','overlay.gdshader')
New-Item -ItemType Directory -Path (Join-Path $qaStageRoot 'addons'), (Join-Path $qaStageRoot 'tests\interaction_highlight') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $qaSourceRoot 'addons\interaction_highlight') -Destination (Join-Path $qaStageRoot 'addons') -Recurse
Get-ChildItem -LiteralPath (Join-Path $qaSourceRoot 'tests\interaction_highlight') -File | Where-Object { $_.Extension -notin @('.log','.pyc') } | Copy-Item -Destination (Join-Path $qaStageRoot 'tests\interaction_highlight')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'isolated_project.godot') -Destination (Join-Path $qaStageRoot 'project.godot')
$qaEntries = foreach ($qaName in $qaCoreNames) {
    $qaSource = Join-Path $qaSourceRoot ('addons\interaction_highlight\' + $qaName)
    $qaDest = Join-Path $qaStageRoot ('addons\interaction_highlight\' + $qaName)
    $qaHash = (Get-FileHash -LiteralPath $qaSource -Algorithm SHA256).Hash
    $qaCopiedHash = (Get-FileHash -LiteralPath $qaDest -Algorithm SHA256).Hash
    if ($qaHash -ne $qaCopiedHash) { throw "Core changed during staging: $qaName" }
    [pscustomobject]@{file=$qaName; sha256=$qaHash; copy_sha256=$qaCopiedHash}
}
# Generated provenance, not a runtime requirement. No source machine paths.
[pscustomobject]@{core_files=$qaEntries; logical_canvas=@(1920,1080); stretch_mode='canvas_items'} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $qaStageRoot 'stage_core_manifest.json') -Encoding utf8
Write-Output "FRESH_GPU_STAGE: $qaStageRoot"

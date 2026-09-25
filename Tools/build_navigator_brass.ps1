param([switch]$Check, [string]$PreviewPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -Path (Join-Path $PSScriptRoot 'NavigatorBrassAssets.cs')
$assetRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'Media/Textures/Window'
$masters = @{
    'fp_navigator_corner_Master_1254x1254.png' = '4DC7B4139BBE7F46B629897BB65FFCBD963A07AB13BAFB5ECD1F3666B3DDF99F'
    'fp_navigator_horz_Master_2172x724.png' = '301A06CC53DC8622C4DA11B257B73BAF6E0B5540DE55EEF956047C5719A4E3F8'
    'fp_navigator_vert_Master_887x1774.png' = 'F6F58716E7DA0AFF2A949D22C919557DD7CB67938647D6F4211E2748C9D0C83B'
}
foreach ($entry in $masters.GetEnumerator()) {
    if ((Get-FileHash -LiteralPath (Join-Path $assetRoot $entry.Key)).Hash -ne $entry.Value) {
        throw "Master changed; review the crop/profile coordinates before rebuilding: $($entry.Key)"
    }
}
[NavigatorBrassAssets]::Build($assetRoot, $Check.IsPresent, $PreviewPath)
Write-Output 'PASS: master hashes, dimensions/alpha, matching thin rails, exact tile endpoints and corner joins; deterministic runtime assets'

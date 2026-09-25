param([switch]$Check, [string]$PreviewPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -Path (Join-Path $PSScriptRoot 'NavigatorBrandAsset.cs')
$assetRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'Media/Textures/Window'
$master = Join-Path $assetRoot 'fp_navigator_brand_Master_1942x809.png'
$expectedHash = '861A0302D2AAF467508B6ECF796D2B8FF40B8B931E87E5CEFA635DF34D4035F8'
if ((Get-FileHash -LiteralPath $master).Hash -ne $expectedHash) { throw 'Master changed; review extraction before building' }
[NavigatorBrandAsset]::Build($master, (Join-Path $assetRoot 'fp_navigator_brand_plaque.tga'), $Check.IsPresent, $PreviewPath)
if ((Get-FileHash -LiteralPath $master).Hash -ne $expectedHash) { throw 'Master changed during build' }
Write-Output 'PASS: master preserved, complete silhouette/metal, real alpha, uniform area resampling, runtime bytes'

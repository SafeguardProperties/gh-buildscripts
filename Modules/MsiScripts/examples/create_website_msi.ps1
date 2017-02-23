Import-Module ..\Write-Msi.psm1 -Force

Write-Msi -ApplicationName SPIGlass -ApplicationType WebSite -UpgradeGuid 4737ed4a-67a3-4a37-8b44-4a11782b88c4 -Version 1.0.0.0 -SourceDir C:\Deploy\SPIGlass -SourceRootDir SPIGlass -OutputDir C:\Deploy\wxs
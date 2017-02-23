<# 
 .Synopsis
  Creates an MSI for deliverables found in SourceDir folder

 .Description
  This module uses the .NET TextTransform utility along with the createwxs.tt text
  template in order to generate WiX fragments for a given deliverables directory.
  The WiX toolset utilities, candle and light, are then executed in order to
  generate an MSI from the .wxs file which was created from the text template.
  This module assumes that TextTransform.exe and the WiX toolset binaries are
  somewhere in the system path.  It also assumes that the createwxs.tt file is in
  the working directory or the same directory as the module.

 .Parameter ApplicationName
  The base name of the MSI, the MSI ProductName, usually the name of the Visual
  Studio Project

 .Parameter ApplicationType
  The application type, this determines how the MSI is built.
  Valid types are: WinApp, WebSite, WebService, WinService, PollManager,
  WorkManager, WorkHandler, PollHandler, GenericPoller, GenericWorker
  
 .Parameter HandlerNames
  An optional parameter which contains a comma delimited list of handler names
  for a WorkHandler or PollHandler.

 .Parameter UpgradeGuid
  The upgrade GUID of the MSI. Its important for this to be constant for a given
  deliverable from build to build. Probably the assembly GUID from AssemblyInfo.cs.

 .Parameter Version
  The version of the MSI which should be the same as the version in AssemblyInfo.cs.

 .Parameter SourceRootDir
  Relative path of the project root directory.  This is used to create a deterministic guid.
  This is only important if one needs the ability to update/patch MSIs.  Otherwise, the
  absolute path of the project root directory can be used.
  
 .Parameter SourceDir
  The directory to crawl which contains the deliverables
  
 .Parameter OutputDir
  The directory where the MSI will be written

 .Examples
  
  Write-Msi -ApplicationName SPIGlassService -ApplicationType WorkHandler -HandlerNames SPIGLASS -UpgradeGuid 2711d933-f78d-4ed5-a6e2-f372e76a4958 -Version 1.0.0.0 -SourceDir C:\Safeguard\ServicesTeam\WorkHandlers\Development\WorkHandlers.SPIGlass\SPIGlassService\bin\Debug -SourceRootDir WorkHandlers.SPIGlass\SPIGlassService -OutputDir C:\Safeguard\ServicesTeam\WorkHandlers\Development\WorkHandlers.SPIGlass\SPIGlassService\wxs

  Write-Msi -ApplicationName WorkManagerService -ApplicationType WorkManager -UpgradeGuid 5bd26d3d-de03-4c5d-87d9-28d2ff40d1fe -Version 1.0.0.0 -SourceDir C:\Safeguard\ServicesTeam\Service\Development\Source\ServiceBus\ServiceBus.Core\WorkManagerService\bin\Debug -SourceRootDir ServiceBus\ServiceBus.Core\WorkManagerService -OutputDir C:\Safeguard\ServicesTeam\Service\Development\Source\ServiceBus\ServiceBus.Core\WorkManagerService\wxs
  
  Write-Msi -ApplicationName SPIGlass -ApplicationType WebSite -UpgradeGuid 4737ed4a-67a3-4a37-8b44-4a11782b88c4 -Version 1.0.0.0 -SourceDir C:\Deploy\SPIGlass -SourceRootDir SPIGlass -OutputDir C:\Deploy\wxs

#>
function Write-Msi {
param(
    [string] $applicationName,
    [string] $applicationType,
    [string] $upgradeGuid,
    [string] $version,
    [string] $sourceRootDir,
    [string] $sourceDir,
    [string] $outputDir,
    [string] $handlerNames = "",
	[string] $containsPreReleaseNuget = "false",
	[string] $createShortcut = "false"
    )    

    $outputDir = $outputDir.Trim('\')

	$handlerNames = $handlerNames.Replace(" ", [string]::Empty)
	
    $PSScriptRoot = Split-Path -Path $script:MyInvocation.MyCommand.Path

    $args = @()
    $args += "-a !!ApplicationName!`"$($applicationName)`""
    $args += "-a !!ApplicationType!$($applicationType)"
    $args += "-a !!HandlerNames!`"$($handlerNames)`""
    $args += "-a !!UpgradeGuid!$($upgradeGuid)"
    $args += "-a !!Version!$($version)"
    $args += "-a !!SourceRootDir!$($sourceRootDir)"
    $args += "-a !!SourceDir!`"$($sourceDir)`""
    $args += "-a !!OutputDir!`"$($outputDir)`""
	$args += "-a !!ContainsPreReleaseNuget!$($containsPreReleaseNuget)"
	$args += "-a !!CreateShortcut!$($createShortcut)"
    $args += "$($PSScriptRoot)\createwxs.tt"   
	
    $ttArgString = $args -join ' '
    $ttCommand = "TextTransform.exe $($ttArgString)"
    
    Write-Host "Write-Msi --> Running TextTranform.exe utility:"
    Write-Host $ttCommand
    
    Start-Process TextTransform.exe -ArgumentList $args -wait
	
    $basePath = [System.IO.Path]::Combine("$($outputDir)","$($applicationName)_v$($version)")	
    $fragmentPath = "$($basePath).wxs"
    $wixobjPath = "$($basePath).wixobj"
	
	$preTag = @{$true="_Prerelease";$false=""}[$containsPreReleaseNuget -eq "true"]
    $msiPath = "$($basePath)$($preTag).msi"
    
    candle.exe $($fragmentPath) -ext WixIisExtension -out $($wixobjPath)
    
    light.exe $($wixobjPath) -ext WixIisExtension -out $($msiPath)
	
	#cleanup
	#Get-ChildItem -path $outputDir -filter "$($applicationName)_v$($version)*" | ? { $_.Extension.ToLower() -ne ".msi" } | Remove-Item -Force
}
export-modulemember -function Write-Msi
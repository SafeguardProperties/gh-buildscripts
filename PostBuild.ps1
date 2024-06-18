# fake fake fake
#$env:REPO_CHECKOUT_PATH = "C:\actions-runner\_work\SPINext-WorkHandler-Utility\SPINext-WorkHandler-Utility"
#$env:RELEASE_VERSION_ONLY = "1.0.1"

#setup output folders
$outputRoot = "C:\WixBuilds\"

# setup variables
Write-Host "Script Root: $($PSScriptRoot)" 
Write-Host "Repository: $($env:REPOSITORY)"
Write-Host "Repository Checkoout Path: $($env:REPO_CHECKOUT_PATH)"
Write-Host "Version: $($env:RELEASE_VERSION_ONLY)"
$version = $env:RELEASE_VERSION_ONLY

# $dropRoot = "H:\BuildDrop\"

# #default the version to 1.0.0 for DEV builds. If tagged build this value will be set appropriately
# $isDevBuild = $true
# $version = "1.0.0" 

# #get script root path
# $PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# #import build modules
Import-Module -Force "$($PSScriptRoot)\Modules\_ImportBuildModules.psm1"

# $REGEX_PATTERN_VERSION = '^[v]([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])$'
# $REGEX_PATTERN_VERSION_NUGET_PRE = '^[v]([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])(-pre)(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])$'
# if([System.Text.RegularExpressions.Regex]::IsMatch($env:BUILD_SOURCEBRANCHNAME, $REGEX_PATTERN_VERSION) -or [System.Text.RegularExpressions.Regex]::IsMatch($env:BUILD_SOURCEBRANCHNAME, $REGEX_PATTERN_VERSION_NUGET_PRE))
# {
#     $isDevBuild = $false

#     #remove "v" prefix
#     $version = $env:BUILD_SOURCEBRANCHNAME.Substring(1)
# }


# #create destination folder if not exist
# $fullOutputRootPath = Join-Path $outputRoot $env:BUILD_DEFINITIONNAME
# if(-not (Test-Path $fullOutputRootPath))
# {
# 	New-Item -path $fullOutputRootPath -type directory
# }

# $fullOutputRootPathFiles = Join-Path $fullOutputRootPath "\*"
# Remove-Item $fullOutputRootPathFiles

#******************************************************************************************************************* 

#find all solution files
$solutionFiles = Get-ChildItem "$($env:REPO_CHECKOUT_PATH)" -recurse -include *.sln

Write-Host "sln count: $($solutionFiles.Count)"

if($solutionFiles.Count -ne 0)
{
	$solutionFiles | % {	
        Write-Host "Publish-Deliverables -SlnPath `"$($env:REPO_CHECKOUT_PATH)`" -BinRootPath `"$($env:REPO_CHECKOUT_PATH)`" -Version $($version) -OutputRootPath `"$($fullOutputRootPath)`""
        Publish-Deliverables -SlnPath "$($_.DirectoryName)" -BinRootPath "$($env:REPO_CHECKOUT_PATH)" -Version $version -OutputRootPath "$($fullOutputRootPath)"
	}
}

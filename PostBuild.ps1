#setup output folders
$outputRoot = "H:\TFS\WixBuilds\"
$dropRoot = "H:\BuildDrop\"

#default the version to 1.0.0 for DEV builds. If tagged build this value will be set appropriately
$isDevBuild = $true
$version = "1.0.0" 

#get script root path
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

#import build modules
Import-Module -Force "$($PSScriptRoot)\Modules\_ImportBuildModules.psm1"

$REGEX_PATTERN_VERSION = '^[v]([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])$'
$REGEX_PATTERN_VERSION_NUGET_PRE = '^[v]([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])(-pre)(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])$'
if([System.Text.RegularExpressions.Regex]::IsMatch($env:BUILD_SOURCEBRANCHNAME, $REGEX_PATTERN_VERSION) -or [System.Text.RegularExpressions.Regex]::IsMatch($env:BUILD_SOURCEBRANCHNAME, $REGEX_PATTERN_VERSION_NUGET_PRE))
{
    $isDevBuild = $false

    #remove "v" prefix
    $version = $env:BUILD_SOURCEBRANCHNAME.Substring(1)
}

#create destination folder if not exist
$fullOutputRootPath = Join-Path $outputRoot $env:BUILD_DEFINITIONNAME
if(-not (Test-Path $fullOutputRootPath))
{
	New-Item -path $fullOutputRootPath -type directory
}

#******************************************************************************************************************* 

#find all solution files
$solutionFiles = Get-ChildItem "$($env:BUILD_SOURCESDIRECTORY)" -recurse -include *.sln

Write-Host "sln count: $($solutionFiles.Count)"

if($solutionFiles.Count -ne 0)
{
	$solutionFiles | % {	
		#$solutionName = $_.Name.Replace(".sln", [string]::Empty)

        $binRootPath = Join-Path $Env:BUILD_ARTIFACTSTAGINGDIRECTORY "drop"
        Write-Host "Publish-Deliverables -SlnPath `"$($_.DirectoryName)`" -BinRootPath `"$($binRootPath)`" -Version $($version) -OutputRootPath `"$($fullOutputRootPath)`""
        Publish-Deliverables -SlnPath "$($_.DirectoryName)" -BinRootPath "$($binRootPath)" -Version $version -OutputRootPath "$($fullOutputRootPath)"

	}
}

#******************************************************************************************************************* 

if($isDevBuild)
{
    $deployScriptRoot = Join-Path (Get-Item $PSScriptRoot).Parent.FullName "Tfs-DeployScripts\"
	$deployScriptPath = Join-Path $deployScriptRoot "Deploy.ps1"
	Set-Location -Path $deployScriptRoot
	$deployScriptCommand = '& "$deployScriptPath" -env "dev01" -msiRootPath "Development\$($env:BUILD_DEFINITIONNAME)"'
	Invoke-Expression $deployScriptCommand
}
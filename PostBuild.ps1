# fake fake fake - only used when manually debugging scripts
#$env:REPO_CHECKOUT_PATH = "C:\actions-runner\_work\SPINext-WorkHandler-Utility\SPINext-WorkHandler-Utility"
#$env:RELEASE_VERSION_ONLY = "1.0.1"

#setup output folders
$outputRoot = "C:\actions-runner\_wixbuilds\"

# setup variables
Write-Host "Script Root: $($PSScriptRoot)" 
Write-Host "Repository: $($env:REPOSITORY)"
Write-Host "Repository Checkoout Path: $($env:REPO_CHECKOUT_PATH)"
Write-Host "Version: $($env:RELEASE_VERSION_ONLY)"
$version = $env:RELEASE_VERSION_ONLY

# #import build modules
Import-Module -Force "$($PSScriptRoot)\Modules\_ImportBuildModules.psm1"

#find all solution files
$solutionFiles = Get-ChildItem "$($env:REPO_CHECKOUT_PATH)" -recurse -include *.sln

Write-Host "sln count: $($solutionFiles.Count)"

if($solutionFiles.Count -ne 0)
{
	$solutionFiles | % {	
        Write-Host "Publish-Deliverables -SlnPath `"$($env:REPO_CHECKOUT_PATH)`" -BinRootPath `"$($env:REPO_CHECKOUT_PATH)`" -Version $($version) -OutputRootPath `"$($outputRoot)`""
        Publish-Deliverables -SlnPath "$($_.DirectoryName)" -BinRootPath "$($env:REPO_CHECKOUT_PATH)" -Version $version -OutputRootPath "$($fullOutputRootPath)"
	}
}

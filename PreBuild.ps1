 # get script root path
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# setup variables
Write-Host "Script Root: $($PSScriptRoot)" 
Write-Host "Repository Checkoout Path: $($env:REPO_CHECKOUT_PATH)"
Write-Host "Version: $($env:RELEASE_VERSION_ONLY)"
$versionOnly = $env:RELEASE_VERSION_ONLY

# update AssemblyInfo(s) so the built version matches the version tag
$assemblyInfoFiles = Get-ChildItem $env:REPO_CHECKOUT_PATH AssemblyInfo.cs -recurse
foreach ($file in $assemblyInfoFiles) 
{ 
    if($file.Directory.Parent.Name -eq "Safeguard.Library.Universal.Contracts"){ continue }

    Write-Host "Applying version: $AssemblyVersion -> $($file.FullName)"
    $tempFile = $file.FullName + ".tmp"
    Get-Content $file.FullName |
    %{$_ -replace 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', "AssemblyVersion(""$versionOnly"")" } |
    %{$_ -replace 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', "AssemblyFileVersion(""$versionOnly"")" }  > $tempFile
    Move-Item $tempFile $file.FullName -force
}

#if we don't have AssemblyInfo(s) assume newer build customization
if($assemblyInfoFiles -eq $null)
{
    Write-Host "Applying version: Directory.build.props"
	$xml = @"
<Project>
 <PropertyGroup>
   <Version>$version</Version>
 </PropertyGroup>
</Project>
"@
    $filename = Join-Path $env:REPO_CHECKOUT_PATH "Directory.build.props"
    $xml | Out-File -FilePath $filename
}

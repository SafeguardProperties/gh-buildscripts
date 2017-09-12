$REGEX_PATTERN_VERSION = '^[v]([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])$'
$REGEX_PATTERN_VERSION_NUGET_PRE = '^[v]([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])(-pre)(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])$'
if([System.Text.RegularExpressions.Regex]::IsMatch($env:BUILD_SOURCEBRANCHNAME, $REGEX_PATTERN_VERSION) -or [System.Text.RegularExpressions.Regex]::IsMatch($env:BUILD_SOURCEBRANCHNAME, $REGEX_PATTERN_VERSION_NUGET_PRE))
{
	#remove v prefix
    $version = $env:BUILD_SOURCEBRANCHNAME.Substring(1)
	$versionSimple = ''
	
	#nuget prerelease will be suffixed with "-pre001", strip this for assembly versioning
	$versionPreIndex = $version.IndexOf("-pre")
	if($versionPreIndex -ge 0)
	{
		$versionSimple = $version.Substring(0, $versionPreIndex) 
	}

    #update AssemblyInfo(s) so the built version matches the version tag
    $assemblyInfoFiles = Get-ChildItem $env:BUILD_SOURCESDIRECTORY AssemblyInfo.cs -recurse
    foreach ($file in $assemblyInfoFiles) 
    { 
		if($file.Directory.Parent.Name -eq "Safeguard.Library.Universal.Contracts"){ continue }
	
	    Write-Host "Applying version: $AssemblyVersion -> $($file.FullName)"
	    $tempFile = $file.FullName + ".tmp"
	    Get-Content $file.FullName |
	    %{$_ -replace 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', "AssemblyVersion(""$versionSimple"")" } |
	    %{$_ -replace 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', "AssemblyFileVersion(""$versionSimple"")" }  > $tempFile
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
		$filename = Join-Path $env:BUILD_SOURCESDIRECTORY "Directory.build.props"
		Out-File -FilePath $filename
	}
}





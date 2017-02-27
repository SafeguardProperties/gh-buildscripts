function Publish-Deliverables
{
    Param
    (
	[string]$SlnPath = $null,
	[string]$BinRootPath,
	[string]$Version,
	[string]$OutputRootPath,
	[string]$appNameSuffix
    )

    trap 
    { 
        Write-Error $_ 
        exit 1 
    }     

	if(-not ([string]::IsNullOrEmpty($SlnPath)))
	{
	    if(-not (Test-Path $SlnPath))
		{
	    Write-Error ("Publish-Deliverables --> SlnPath parameter is missing or directory does not exist.")
	    exit 1
		}
	}

	if(-not $OutputRootPath -or -not (Test-Path $OutputRootPath))
    {
        Write-Error ("Publish-Deliverables --> OutputRootPath parameter is missing or directory does not exist.")
	    exit 1
    }

	if(-not $BinRootPath -or -not (Test-Path $BinRootPath))
    {
        Write-Error ("Publish-Deliverables --> BinRootPath parameter is missing or directory does not exist.")
	    exit 1
    }
	
	#validate that version matches either v1.0.0 or v1.0.0-pre001
	$REGEX_PATTERN_VERSION = "^([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])$"	
	$REGEX_PATTERN_VERSION_NUGET_PRE = "^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])(-pre)(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])$"
	$isNugetPrerelease = [Regex]::IsMatch($Version,$REGEX_PATTERN_VERSION_NUGET_PRE)
    if(-not $Version -or (-not [Regex]::IsMatch($Version,$REGEX_PATTERN_VERSION) -and -not $isNugetPrerelease))
    {
        Write-Error ("Publish-Deliverables --> Version parameter is missing or invalid.")
	    exit 1
    }
	
	#Deliverables.xml at the solution root is our BUILD manifest, if it doesn't exist I guess you didn't want any MSI output.  silly goose
    $deliverablesPath = $null
	if(-not ([string]::IsNullOrEmpty($SlnPath)))
	{
		if((Test-Path $SlnPath)){
		$deliverablesPath = Join-Path $SlnPath "Deliverables.xml"
		}
	}
	else
	{
		$deliverablesPath = Join-Path $BinRootPath "Deliverables.xml"
	}
	
    if(-not (Test-Path $deliverablesPath))
    {
        Write-Host ("Publish-Deliverables --> Deliverables.xml not found.")
	    exit 0
    }
	
	#parse Deliverables.xml
	[Reflection.Assembly]::LoadWithPartialName("System.Xml.Linq") | Out-Null
	$xdoc = [System.Xml.Linq.XDocument]::Load($deliverablesPath)
	$apps = $xdoc.Element("Applications").Elements("Application")
	$apps | % { 

		#setup for msi build using manifest
		$appType = $_.Attribute("Type").Value 		
		$appName = $_.Attribute("Name").Value 
		if(-not ([string]::IsNullOrEmpty($appNameSuffix)))
		{
			$appName = "$($appName)_$($appNameSuffix)"
		}
		$appSourceDirectory = $_.Attribute("SourceDirectory").Value 
		
		#CreateShorcut
		$createShortcut = "false"
		if($_.Attribute("CreateShortcut") -ne $null -and $_.Attribute("CreateShortcut").Value.ToUpper() -eq "TRUE"){ $createShortcut = "true"; }
		
		
		#if the version is "prerelease" and this app is NOT nuget, we're not building it.  continue
		if($appType.ToUpper() -ne "NUGET" -and $isNugetPrerelease){return} #behaves like a continue in powershell due to ForEach-Object context (e.g. %)}
		
		#if arguments exist, strip spaces.  We are currently not using these arguments, but if we DO need them.  Here they are.
		$appArguments = @()
		if($_.Attribute("Arguments") -ne $null){ $appArguments = ($_.Attribute("Arguments").Value.Split(',') | % {$_.Trim()}) }

		#**************************************************
		#if there is no Solution Path, simple package of BinRootPath
		$projectBinPath = $null
		if(([string]::IsNullOrEmpty($SlnPath)))	
		{
			$projectBinPath = Join-Path $BinRootPath $appSourceDirectory
		}
		else
		{
			#get the project in the appSourceDirectory
			$csProjFile = Get-ChildItem (Join-Path $SlnPath $appSourceDirectory) -filter "*.csproj"
			if($csProjFile -ne $null -and $csProjFile.Name -ne $null -and $csProjFile.Name.Length -gt 0)
			{
				$projectName = $csProjFile.Name.Replace(".csproj", [string]::Empty)
				$projectBinPath = Join-Path $BinRootPath $projectName
			}
		}

		#web applications will put their output in a publish folder, if building a website tack this on
		if($appType.ToUpper() -eq "WEBSITE")
		{ 
			$projectBinPathWebApplicationPath = Join-Path $projectBinPath "_PublishedWebsites\$($projectName)" 
			if(Test-Path $projectBinPathWebApplicationPath)
			{
				$projectBinPath = $projectBinPathWebApplicationPath
			}
		}
        
		#*****************************************
		if(Test-Path $projectBinPath)
		{
			$appGuid = ""
			if(-not ([string]::IsNullOrEmpty($SlnPath)))
			{
				#get the assembly guid
				$assemblyInfoCsPath = Join-Path (Join-Path $SlnPath $appSourceDirectory) "Properties\AssemblyInfo.cs"
				Write-Host "Publish-Deliverables --> assemblyInfoCsPath - `"$($assemblyInfoCsPath)`""
				$appGuid = Get-AssemblyInfoGuid $assemblyInfoCsPath			
				
				#examine packages.config (if it exists) to determine if any prerelease packages have been referenced
				$preReleaseNugetReferences = $false
				$packagesConfigPath = Join-Path (Join-Path $SlnPath $appSourceDirectory) "packages.config"
				if(Test-Path $packagesConfigPath)
				{
					$packagesConfigXdoc = [System.Xml.Linq.XDocument]::Load($packagesConfigPath)
					$preReleaseNugetReferences = ($packagesConfigXdoc.Element("packages").Elements("package") | ? { $_.Attribute("version").Value.Contains("-pre") }) -ne $null	  
				}
			}
			
			if($appType.ToUpper() -eq "NUGET")
			{
				#################################################
				##  Publish NuGet
				#################################################
				
				#don't allow release nuget packages to contain prerelease references
				if($preReleaseNugetReferences -and -not $isNugetPrerelease)
				{
					Write-Error ("Publish-Deliverables --> Release NuGet packages may not contain Pre-release NuGet packages references.")
					exit 1
				}
				
				
				$projNuspecFiles = $null
				if(-not ([string]::IsNullOrEmpty($SlnPath)))
				{
					#validate a nuspec file exists and copy it to the bin path (it will be packaged at this location)
					$projNuspecFiles = Get-ChildItem (Join-Path $SlnPath $appSourceDirectory) -filter "*.nuspec"
				}
				else
				{
					$projNuspecFiles = Get-ChildItem (Join-Path $BinRootPath $appSourceDirectory) -filter "*.nuspec"
				}
				
				if($projNuspecFiles -eq $null)
				{
					$projectRootPath = (Join-Path $SlnPath $appSourceDirectory)
					Write-Error ("Publish-Deliverables --> Deliverables.xml specified project ($($projectName)) as type NUGET, but no nuspec file(s) found at: $($projectRootPath)")
					exit 1
				}
				else
				{
					if(-not ([string]::IsNullOrEmpty($SlnPath)))
					{
						$projNuspecFiles | % {
							Copy-Item $_.FullName -Destination $projectBinPath -Force
						}
					}
				}
				
				#get the path to the nuget.exe and create the nugetpackage
				$nugetPath = Join-Path (Get-Item $PSScriptRoot).parent.FullName "Nuget"
				
				Write-Host "Publish-NugetPackage $($projectBinPath) $($nugetPath) $($Version) "
				
				Publish-NugetPackage "$projectBinPath" "$nugetPath" $Version
			}
			else 
			{				
				#################################################
				##  Publish MSI
				#################################################
				
				#contains prerelease nuget packages
				$containsPreReleaseNuget = @{$true="true";$false="false"}[$preReleaseNugetReferences]
				$handlerNames = ""
				if($appType.ToUpper() -eq "WORKHANDLER")
				{
					$handlers = Get-WorkHandlers "$($projectBinPath)"
					if($handlers -ne $null){
						$handlerNames = [string]::Join(",", $handlers)
					}else{
						Write-Error "Publish-Deliverables --> Get-WorkHandlers for `"$($projectBinPath)`" returned no results."
					}
				}
				
				if($appType.ToUpper() -eq "POLLHANDLER")
				{
					$handlers = Get-PollHandlers "$($projectBinPath)"
					if($handlers -ne $null){
						$handlerNames = [string]::Join(",", $handlers)
					}else{
						Write-Error "Publish-Deliverables --> Get-PollHandlers for `"$($projectBinPath)`" returned no results."
					}
				}
				
				#create the msi in the local output folder
                Write-Host "Write-Msi -ApplicationName `"$($appName)`" -ApplicationType $appType -UpgradeGuid $appGuid -Version $Version -SourceDir `"$($projectBinPath)`" -OutputDir $OutputRootPath -HandlerNames `"$($handlerNames)`" -ContainsPreReleaseNuget $containsPreReleaseNuget -CreateShortcut $createShortcut"
				Write-Msi -ApplicationName "$($appName)" -ApplicationType $appType -UpgradeGuid $appGuid -Version $Version -SourceDir "$($projectBinPath)" -OutputDir $OutputRootPath -HandlerNames "$($handlerNames)" -ContainsPreReleaseNuget $containsPreReleaseNuget -CreateShortcut $createShortcut
				
				#move output to drop folder
				$preTag = @{$true="_Prerelease";$false=""}[$containsPreReleaseNuget -eq "true"]
				
				$msiPath = Join-Path $OutputRootPath "$($appName)_v$($version)$($preTag).msi" 
				if(Test-Path "$($msiPath)")
				{
                        $dropFolder = "Release"
                        if(($env:BUILD_DEFINITIONNAME).StartsWith("DEV -") -eq $true)
                        {
                            $dropFolder = "Development"
                        }

                        Write-Host "Write-S3Object -ProfileName BuildService -BucketName sgpdevelopedsoftware -File $($msiPath) -Key `"$($dropFolder)/$($env:BUILD_DEFINITIONNAME)/$($appName)_v$($version)$($preTag).msi`""

                        Write-S3Object -ProfileName BuildService -BucketName sgpdevelopedsoftware -File $msiPath -Key "$($dropFolder)/$($env:BUILD_DEFINITIONNAME)/$($appName)_v$($version)$($preTag).msi"
				}
				else
				{
					Write-Error "Publish-Deliverables --> Missing: $($msiPath)"
					Write-Error "Publish-Deliverables --> Write-Msi `"$($appName)`" did not produce MSI."
					exit 1
				}
			}
		}	
				
		
	}
}

#########################################
Export-ModuleMember -function Publish-Deliverables
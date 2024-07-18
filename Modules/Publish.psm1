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

	if(-not $OutputRootPath)
    {
        Write-Error ("Publish-Deliverables --> OutputRootPath parameter is missing or directory does not exist.")
	    exit 1
    }
	if (-Not (Test-Path -Path $OutputRootPath -PathType Container)) {
		# create OutputRootPath
		New-Item -Path $OutputRootPath -ItemType Directory
		Write-Host "Directory created: $directoryPath"
	}

	if(-not $BinRootPath -or -not (Test-Path $BinRootPath))
    {
        Write-Error ("Publish-Deliverables --> BinRootPath parameter is missing or directory does not exist.")
	    exit 1
    }

	#validate that version matches either v1.0.0 or v1.0.0-pre001
	$REGEX_PATTERN_VERSION = "^([0-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])$"
	$REGEX_PATTERN_VERSION_NUGET_PRE = "^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])(-pre)(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])$"
#	$REGEX_PATTERN_VERSION = "^\d+\.\d+\.\d+(\.(?:[1-9]|[1-9]\d{1,3}|[1-5]\d{4}|6[0-4]\d{3}|65[0-4]\d{2}|655[0-2]\d|6553[0-5]))?$"
#	$REGEX_PATTERN_VERSION_NUGET_PRE = "^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])\.([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-4])(-pre)(00[1-9]|0[1-9][0-9]|[1-9][0-9][0-9])$"
	$isNugetPrerelease = [Regex]::IsMatch($Version,$REGEX_PATTERN_VERSION_NUGET_PRE)
	$isRegularRelease = [Regex]::IsMatch($Version,$REGEX_PATTERN_VERSION_NUGET)
    if(-not $Version -or (-not [Regex]::IsMatch($Version,$REGEX_PATTERN_VERSION) -and -not $isNugetPrerelease))
    {
		Write-Host ("Version: $Version")
		Write-Host ("isNugetPrerelease: $isNugetPrerelease")
		Write-Host ("isRegularRelease: $isRegularRelease")
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

	#exit without error if no manifest
    if(-not (Test-Path $deliverablesPath))
    {
        Write-Host ("Publish-Deliverables --> Deliverables.xml not found.")
	    exit 0
    }

#	#only when DEV, remove any existing objects from drop
#	if(($env:BUILD_DEFINITIONNAME).StartsWith("DEV -") -eq $true)
#	{
#		$existingObjects = Get-S3Object -ProfileName BuildService -BucketName sgpdevelopedsoftware -KeyPrefix "Development/$($env:BUILD_DEFINITIONNAME)/"
#		foreach($eo in $existingObjects)
#		{
#			Write-Host "Executing Remove-S3Object -ProfileName BuildService -BucketName sgpdevelopedsoftware -Key `"$($eo.Key)`""
#			#todo Remove-S3Object here
#			Remove-S3Object -Force -ProfileName BuildService -BucketName sgpdevelopedsoftware -Key "$($eo.Key)"
#		}
#	}

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
				#$projectName = $csProjFile.Name.Replace(".csproj", [string]::Empty)
				#$projectBinPath = Join-Path (Join-Path $BinRootPath $projectName) "bin\Release"
				#$projectBinPath = Join-Path (Join-Path $BinRootPath $appSourceDirectory) "bin\Release"

				$projDir = $csProjFile.Directory.Name
				$projectName = [System.IO.Path]::GetFileNameWithoutExtension($csProjFile.FullName)
				$projectBinPath = Join-Path (Join-Path (Join-Path $BinRootPath $projDir) "out") $projectName
			}
		}

		#web applications will put their output in a publish folder, if building a website tack this on
		if($appType.ToUpper() -eq "WEBSITE")
		{
			# $projectBinPathWebApplicationPath = Join-Path $projectBinPath "_PublishedWebsites\$($projectName)"
			# if(Test-Path $projectBinPathWebApplicationPath)
			# {
			# 	$projectBinPath = $projectBinPathWebApplicationPath
			# }
			$projectBinPath = Join-Path (Join-Path (Join-Path (Join-Path (Join-Path $BinRootPath $appSourceDirectory) "out") $appSourceDirectory) "_PublishedWebsites") $appSourceDirectory
		}

		#*****************************************
		if(Test-Path $projectBinPath)
		{
			$appGuid = ""
			if(-not ([string]::IsNullOrEmpty($SlnPath)))
			{
				#get the assembly guid
				$assemblyInfoCsPath = Join-Path (Join-Path $SlnPath $appSourceDirectory) "Properties\AssemblyInfo.cs"

				if(Test-Path $assemblyInfoCsPath)
				{
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
			}

			if($appType.ToUpper() -eq "NUGET")
			{
				#################################################
				##  Publish NuGet
				#################################################

				#if nupkg has been created from build, use it
				$releaseDir = (Join-Path (Join-Path $SlnPath $appSourceDirectory) "bin\Release")
				$debugDir = (Join-Path (Join-Path $SlnPath $appSourceDirectory) "bin\Debug")

				$projNupkgFiles = $null
				if(Test-Path $releaseDir)
				{
					$projNupkgFiles = Get-ChildItem $releaseDir -filter "*.nupkg"
				}
				else
				{
					if($projNupkgFiles -eq $null)
					{
						if(Test-Path $debugDir)
						{
							$projNupkgFiles = Get-ChildItem $debugDir -filter "*.nupkg"
						}
					}
				}

				if($projNupkgFiles -ne $null)
				{
					#get the path to the nuget.exe and create the nugetpackage
					$nugetPath = Join-Path (Get-Item $PSScriptRoot).parent.FullName "Nuget"

					$projNupkgFiles | % {
						Write-Host ("Publish-Nupkg --> $($_.FullName) $($nugetPath)")
						Publish-Nupkg $_.FullName $nugetPath
					}
				}
				else
				{
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

					# copy to s3
					Write-Host "Execute: aws s3 cp $($msiPath) s3://sgpdevelopedsoftware/$($dropFolder)/$($env:REPOSITORY)/$($appName)_v$($version)$($preTag).msi"
					$s3Dest = "s3://sgpdevelopedsoftware/$($dropFolder)/$($env:REPOSITORY)/$($appName)_v$($version)$($preTag).msi"
					$s3CopyCommand = "aws s3 cp `"$msiPath`" `"$s3Dest`""
					Invoke-Expression $s3CopyCommand
					if ($LASTEXITCODE -ne 0) {
						Write-Error "AWS S3 copy command failed with exit code $LASTEXITCODE"
						exit 1
					}

					# only deploy types we care about
					$deployTypes = @("WEBSITE", "POLLMANAGER", "WORKMANAGER", "WORKHANDLER", "POLLHANDLER", "GENERICPOLLER", "GENERICWORKER")
					if ($deployTypes -contains $appType.ToUpper()) {
						# deploy
						#Write-Host "Deploy to DEV - $($etcdCmdSetVersionPath) $($env:REPOSITORY) $($appName) $($version)"
						$etcdCmdSetVersionPath = Join-Path $($MyInvocation.PSScriptRoot) "Tool\EtcdCmdSetVersion\EtcdCmdSetVersion.exe"
						$ps = new-object System.Diagnostics.Process
						$ps.StartInfo.Filename = $etcdCmdSetVersionPath
						$ps.StartInfo.Arguments = "$($env:REPOSITORY) `"$($appName)`" $($version)"
						$ps.StartInfo.RedirectStandardOutput = $True
						$ps.StartInfo.RedirectStandardError = $True
						$ps.StartInfo.UseShellExecute = $false
						$ps.start()
						if(!$ps.WaitForExit(30000))
						{
							$ps.Kill()
						}
						[string] $Out = $ps.StandardOutput.ReadToEnd();
						[string] $ErrOut = $ps.StandardError.ReadToEnd();
						Write-Host "Execute: $($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)"
						if ($ErrOut -ne "")
						{
							Write-Error "EtcdCmdSetVersion Errors"
							Write-Error $ErrOut
						}
						Write-Host $Out
					}
				}
				else
				{
					Write-Error "Publish-Deliverables --> Missing: $($msiPath)"
					Write-Error "Publish-Deliverables --> Write-Msi `"$($appName)`" did not produce MSI."
					exit 1
				}
			}
		}
		else
		{
			Write-Error ("Publish-Deliverables --> projectBinPath not found: $($projectBinPath)")
	    	exit 1
		}


	}
}

#########################################
Export-ModuleMember -function Publish-Deliverables

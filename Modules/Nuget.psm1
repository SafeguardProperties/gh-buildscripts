function Publish-NugetPackage
{
  Param
  (
    [string]$SrcPath,
    [string]$NugetPath,
    [string]$PackageVersion
  )
	   
    #remove all previous packed packages in the directory  
    $allNugetPackageFiles = Get-ChildItem (Join-Path $SrcPath *.nupkg)
	if($allNugetPackageFiles -ne $null)
	{
		foreach ($nupkgFile in $allNugetPackageFiles)
		{ 
			Remove-Item $nupkgFile
		}
	}

	#update version and package all nuspec files into nupkg
	$allNuspecFiles = Get-ChildItem (Join-Path $SrcPath *.nuspec)
    foreach ($file in $allNuspecFiles)
    { 
        Write-Host "Modifying file $($file.FullName)"
		
        #save the file for restore
        $backupFile = $file.FullName + "._ORI"
        $tempFile = $file.FullName + ".tmp"
        Copy-Item $file.FullName $backupFile -Force
		
        #now load all content of the original file and rewrite modified to the same file
        Get-Content $file.FullName |
        %{$_ -replace '<version>[0-9]+(\.([0-9]+|\*)){1,3}</version>', "<version>$PackageVersion</version>" } > $tempFile
        Move-Item $tempFile $file.FullName -force
 
		$symbolsSwitch = ""
		if($file.Name.ToLower().EndsWith(".symbols.nuspec") -eq $true)
		{
			$symbolsSwitch = "-Symbols"
		}
		
 
        #create the .nupkg from the nuspec file
        $ps = new-object System.Diagnostics.Process
        $ps.StartInfo.Filename = Join-Path $NugetPath "nuget.exe"
        $ps.StartInfo.Arguments = "pack `"$file`" $($symbolsSwitch)"
        $ps.StartInfo.WorkingDirectory = $file.Directory.FullName
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
        Write-Host "Nuget pack Output of commandline $($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)"        
        if ($ErrOut -ne "") 
        {
            Write-Error "Nuget pack Errors"
            Write-Error $ErrOut
        }
		else
		{
            # nuget config file
            $nugetConfigFile = Join-Path $env:REPO_CHECKOUT_PATH ".nuget/NuGet.config"

			#move the resulting package to the output directory
			$allNugetPackageFiles = Get-ChildItem (Join-Path $SrcPath *.nupkg)
			foreach($nupkgFile in $allNugetPackageFiles)
			{
                #nuget push
                $ps = new-object System.Diagnostics.Process
                $ps.StartInfo.Filename = "nuget" #Join-Path $NugetPath "nuget.exe"
                $ps.StartInfo.Arguments = "push -Source sgpd/Net45 -ConfigFile $nugetConfigFile `"$nupkgFile`""
                $ps.StartInfo.WorkingDirectory = $nupkgFile.Directory.FullName
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
                Write-Host "Nuget push Output of commandline $($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)"        
                if ($ErrOut -ne "") 
                {
                    Write-Error "Nuget push Errors"
                    Write-Error $ErrOut
                }
			}
		}
		
        #restore original file just for good measure
        Move-Item $backupFile $file -Force
    }    
}

function Publish-Nupkg
{
	Param
	(
	[string]$NupkgFilePath,
	[string]$NugetPath
	)
  
	$nupkgFile = Get-ChildItem $NupkgFilePath
  
	#nuget push
	$ps = new-object System.Diagnostics.Process
	$ps.StartInfo.Filename = "nuget" #Join-Path $NugetPath "nuget.exe"
	$ps.StartInfo.Arguments = "push -Source github -ApiKey $env:GITHUB_TOKEN `"$nupkgFile`""
	$ps.StartInfo.WorkingDirectory = $nupkgFile.Directory.FullName
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
	Write-Host "Nuget push Output of commandline $($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)"        
	if ($ErrOut -ne "") 
	{
		Write-Error "Nuget push Errors"
		Write-Error $ErrOut
	}
}
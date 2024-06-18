 function Get-WorkHandlers
{
	Param
	(
	[string]$Path
	)
	
	$workHandlerBaseTypes = Get-BaseTypes -Path $Path -BaseTypeName "WorkHandlerBase"
	$workHandlerTypes = Get-BaseTypes -Path $Path -BaseTypeName "WorkHandler"
	
	return $workHandlerBaseTypes + $workHandlerTypes
}

function Get-PollHandlers
{
	Param
	(
	[string]$Path
	)
	
	return Get-BaseTypes -Path $Path -BaseTypeName "PollHandlerBase"
}

function Get-BaseTypes
{
	Param
	(
	[string]$Path,
	[string]$BaseTypeName
	)

	trap 
	{ 
		Write-Error $_ 
		#exit 1 
	} 

	if(-not $Path -or -not (Test-Path $Path))
	{
		Write-Error ("Path parameter is missing or invalid.")
		#exit 1
	}    

	$baseClassName = "PollHandlerBase"
F	$monoPath = Join-Path (Get-Item $MyInvocation.PSScriptRoot).parent.FullName "Mono"	
	Add-Type -Path (Join-Path $monoPath "Mono.Cecil.dll")
	
	$returnValue = @()
	$assemblyFiles = Get-ChildItem "$($Path)" -filter "*.dll"
	foreach($file in $assemblyFiles)
	{
		try
		{
			#read assembly definitions
			$assemblyDefinition = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($file.FullName)
			$assemblyTypes = $assemblyDefinition.MainModule.GetTypes()
			foreach($type in $assemblyTypes)
			{
				if($type.BaseType -ne $null)
				{
					if($type.BaseType.Name -eq $BaseTypeName)
					{
						$returnValue += $type.Name
					}
				}
			}
		} catch {
			Write-Host $_ 
		}
	}

	return $returnValue
}

Export-ModuleMember -function Get-WorkHandlers, Get-PollHandlers 

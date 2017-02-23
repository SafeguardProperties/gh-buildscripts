function Get-AssemblyInfoGuid
{
    Param
    (
    [string]$AssemblyInfoCsPath
    )

    trap 
    { 
        Write-Error $_ 
        exit 1 
    } 

    if(-not $AssemblyInfoCsPath -or -not (Test-Path $AssemblyInfoCsPath) -or -not $AssemblyInfoCsPath.EndsWith("AssemblyInfo.cs"))
    {
        Write-Error ("AssemblyInfoCsPath parameter is missing or AssemblyInfo.cs does not exist.")
	    exit 1
    }    

   
    $assemblyInfoFile = Get-ChildItem $AssemblyInfoCsPath
    $assemblyInfoGuid = (Get-Content $assemblyInfoFile.FullName | % { if($_.StartsWith("[assembly: Guid(`"")){ return $_} } ).Replace("[assembly: Guid(`"", [string]::Empty).Replace("`")]", [string]::Empty)
	
    return $assemblyInfoGuid;
}

Export-ModuleMember -function Get-AssemblyInfoGuid
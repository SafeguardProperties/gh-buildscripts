$repositoryUrl = "https://source.sgpdev.com/tfs/SGPD/SGD/_git/Tfs-BuildScripts"

#get the path where this script is executing
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
$buildScriptsPath = $PSScriptRoot

#load the user password from the secure string in a file
$secureStringFile = Join-Path $PSScriptRoot "\password.securestring.svc_build.txt"
$sspassword = cat $secureStringFile | convertto-securestring
$binpassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sspassword)
$plainpassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($binpassword)

#must provide credentials in the path
$repositoryPath = $repositoryUrl.Replace("https://", "https://svc_build:$plainpassword@")

#presence of .git indicates a git repository
$gitFilePath = $buildScriptsPath + '\.git'
if(Test-Path $gitFilePath)
{
	#if the current folder is a git repository, perform a fetch and hard reset (we want whatever is in the repository)
	$ArgumentList = '-C '+ '"' + $buildScriptsPath + '" remote set-url origin ' + '"' + $repositoryPath + '"';
	Start-Process -FilePath git.exe -ArgumentList $ArgumentList -Wait -NoNewWindow;
	$ArgumentList = '-C '+ '"' + $buildScriptsPath + '" fetch -q --all';
	Start-Process -FilePath git.exe -ArgumentList $ArgumentList -Wait -NoNewWindow;
	$ArgumentList = '-C '+ '"' + $buildScriptsPath + '" reset -q --hard origin/master';
	Start-Process -FilePath git.exe -ArgumentList $ArgumentList -Wait -NoNewWindow;
}
else
{
	#if the current folder is not a git repository, remove the current folder and clone from the repository
    Remove-Item $PSScriptRoot -Force -Recurse
    $ArgumentList = 'clone ' + $repositoryPath +' "'+$buildScriptsPath+'"';
	
	$pinfo = New-Object System.Diagnostics.ProcessStartInfo
	$pinfo.FileName = "git.exe"
	$pinfo.RedirectStandardError = $true
	$pinfo.RedirectStandardOutput = $true
	$pinfo.UseShellExecute = $false
	$pinfo.Arguments = $ArgumentList
	$p = New-Object System.Diagnostics.Process
	$p.StartInfo = $pinfo
	$p.Start() | Out-Null
	$p.WaitForExit()
	$stdout = $p.StandardOutput.ReadToEnd()
	$stderr = $p.StandardError.ReadToEnd()
	
	#no idea why cloning a repository is returned on stderr, but let's capture it so our builds don't show this non-error
	if(-not [string]$stderr.StartsWith("Cloning into 'D:\Git\_source\Tfs-BuildScripts'"))
	{
		Write-Error $stderr
	}
	#Write-Host "stdout: $stdout"
	#Write-Host "stderr: $stderr"
	#Write-Host "exit code: " + $p.ExitCode
}

#execute git command

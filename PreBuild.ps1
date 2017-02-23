#get script root path
$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

#get the latest build scripts
$getBuildScriptsScriptPath = Join-Path $PSScriptRoot "GetBuildScripts.ps1"
Invoke-Expression -ErrorAction SilentlyContinue '& "$getBuildScriptsScriptPath"' | Out-Null

#execute the real prebuild tasks
$prebuildTasksScriptPath = Join-Path $PSScriptRoot "PreBuildTasks.ps1"
$prebuildTasksCommand = '& "$prebuildTasksScriptPath"'
Invoke-Expression $prebuildTasksCommand
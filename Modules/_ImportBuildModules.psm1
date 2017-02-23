$PSScriptRoot = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Import-Module "$($PSScriptRoot)\Nuget.psm1" -Force -Verbose
Import-Module "$($PSScriptRoot)\MsiScripts\Write-Msi.psm1" -Force -Verbose
Import-Module "$($PSScriptRoot)\Publish.psm1" -Force -Verbose
Import-Module "$($PSScriptRoot)\AssemblyInfo.psm1" -Force -Verbose
Import-Module "$($PSScriptRoot)\ApplicationLocator.psm1" -Force -Verbose
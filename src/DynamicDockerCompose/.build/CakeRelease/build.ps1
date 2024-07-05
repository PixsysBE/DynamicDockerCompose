param (
	[string]$securePasswordPath,
	[string]$vault,
	[switch]$publishToNuget,
	[string]$publishToSource="",
	[switch]$createGithubRelease,
	[switch]$autoBuild,
	[string]$csprojPath,
	[string]$nuspecFilePath,
	[switch]$verbose
)

$ErrorActionPreference = 'Stop'

$currentDirectory = Get-Location
$cakeReleaseDirectory = $PSScriptRoot

# Import variables and scripts
$scriptsFolder = ".\Powershell\"
. (Join-Path -Path $PSScriptRoot -ChildPath "${scriptsFolder}cakerelease.functions.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "${scriptsFolder}cakerelease.settings.ps1")

# Set location to cakeReleaseDirectory because PSScriptRoot changed due to the imported scripts not in the same folder
Set-Location -LiteralPath $cakeReleaseDirectory

# Ensure script required variables exist
$securePasswordPath = Confirm-String-Parameter -param $securePasswordPath -prompt "Please enter the secure password path" 
$vault = Confirm-String-Parameter -param $vault -prompt "Please enter the vault name" 

# Unlock secret store to get secrets
$password = Import-CliXml -Path $securePasswordPath
Unlock-SecretStore -Password $password
$env:GH_TOKEN = Get-Secret -Name GH_TOKEN -Vault $vault -AsPlainText

$env:NUGET_TOKEN = "notoken"
if($publishToNuget.IsPresent){
	$env:NUGET_TOKEN = Get-Secret -Name NUGET_TOKEN -Vault $vault -AsPlainText
	if([string]::IsNullOrWhiteSpace($env:NUGET_TOKEN)){
		Write-Host "Nuget Api key has not been defined, please update your vault with a NUGET_TOKEN secret"
		exit 1
	}
}

# Additional environments variables
$env:PUBLISH_PACKAGE_TO_NUGET_SOURCE = Format-With-Double-Backslash -string $publishToSource

# Ensure .nuspec has all the properties needed
$nuspecProperties = Confirm-Nuspec-Properties -filePath $nuspecFilePath -verbose:$verbose

# Ensure package.json has all the properties needed
$packageJsonProperties = Confirm-Package-Json-Properties -filePath $packageJsonPath -packageId $nuspecProperties.Id -verbose:$verbose

# Git Hooks
$csprojPath = Get-Csproj-Path -csprojPath $csprojPath
Copy-Git-Hooks -filePath $csprojPath -includePath $csprojTargetGitHooksCommitMsgPath -destinationFolder $csprojTargetGitHooksCommitMsgDestinationFolder -verbose:$verbose

# Create Semantic release config file based on parameters
$releaseConfig = (Get-Content -Path $mainConfigPath) -replace "{%GITHUB%}", $githubConfig
$releaseConfig = $releaseConfig -replace "{%NUGET%}", $nugetConfig
Out-File -FilePath $releaseConfigPath -InputObject $releaseConfig -encoding UTF8

# Cake build
Set-Location -LiteralPath $cakePath

dotnet tool restore
if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory	
	exit $LASTEXITCODE 
}

dotnet cake --projectName $nuspecProperties.Id --rootPath $rootPath --projectPath (Split-Path -Parent $csprojPath) --buildPath $buildPath --nuspecFilePath $nuspecFilePath --changelogVersion $packageJsonProperties.changelogVersion --execVersion $packageJsonProperties.execVersion --gitVersion $packageJsonProperties.gitVersion --semanticReleaseVersion $packageJsonProperties.semanticReleaseVersion

if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory
	exit $LASTEXITCODE 
}

Set-Location -LiteralPath $currentDirectory
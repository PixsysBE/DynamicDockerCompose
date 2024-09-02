[CmdletBinding()]
param (
	# Parameters 
    [string]$projectName,


	# Parameters used in packaged cake release script
	[string]$securePasswordPath,
	[string]$vault,
	[switch]$publishToNuget,
	[string]$publishToSource="",
	[switch]$createGithubRelease,
	[switch]$autoBuild,
	[string]$csprojPath,
	[string]$nuspecFilePath
)

$ErrorActionPreference = 'Stop'

# Directory where the script is called
$currentDirectory = Get-Location
# Directory containing launcher (cakerelease.ps1)
$launcherScriptDirectory = $PSScriptRoot

# Get Cake Release settings
$projectSettingsPath = (Join-Path -Path $launcherScriptDirectory -ChildPath "../../.config/CakeRelease.settings.json") | Resolve-Path
if (Test-Path -Path $projectSettingsPath) {
	try {
		$jsonContent = Get-Content -Path $projectSettingsPath -Raw | ConvertFrom-Json
		$objectList = @($jsonContent)
	} catch {
		Write-Host "Error while reading JSON file: $_" -ForegroundColor Red
		return
	}
	if($objectList.Count -eq 1){
		$projectSettings = $objectList[0]
	}
	else {
		$projectSettings = $objectList | Where-Object { $_.Name -eq $projectName}
	}
    if ($projectSettings) {       
        Write-Verbose "Settings found with name $($projectSettings.Name)"
        $cakeReleaseScriptPath = (Join-Path -Path $projectSettings.PackageDirectory -ChildPath ".build/CakeRelease/cakerelease.ps1") | Resolve-Path
        Write-Verbose "cakeReleaseScriptPath: $cakeReleaseScriptPath"
		# Launch Cake Release script located in package
        & $cakeReleaseScriptPath -launcherScriptDirectory $launcherScriptDirectory -securePasswordPath $securePasswordPath -vault $vault -publishToNuget:$publishToNuget -publishToSource $publishToSource -createGithubRelease:$createGithubRelease -autoBuild:$autoBuild -csprojPath $csprojPath -nuspecFilePath $nuspecFilePath
    } else {
        Write-Host "Settings not found with name $projectName. Please specify your project name (You can check your settings here : $projectSettingsPath)" -ForegroundColor Red
    }    
} else {
    Write-Host "Settings not found at $projectSettingsPath" -ForegroundColor Red
}


Set-Location -LiteralPath $currentDirectory
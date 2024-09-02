[CmdletBinding()]
param (
    # Parameters used in packaged dynamic docker compose script
    [Alias("env-name")]
    [string]$envFileName,
    [string]$template,
    [switch]$up=$false,
    [switch]$down=$false,
    [switch]$list=$false,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$remainingArgs
)

$ErrorActionPreference = 'Stop'

# Directory where the script is called
$currentDirectory = Get-Location
# Directory containing launcher (dynamic-docker-compose.ps1)
$launcherScriptDirectory = $PSScriptRoot

# Get Dynamic Docker Compose settings
$projectSettingsPath = (Join-Path -Path $launcherScriptDirectory -ChildPath "../../.config/DynamicDockerCompose.settings.json") | Resolve-Path
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
        $dynamiDockerComposeScriptPath = (Join-Path -Path $projectSettings.PackageDirectory -ChildPath ".build/DynamicDockerCompose/dynamic-docker-compose.ps1") | Resolve-Path
        Write-Verbose "dynamiDockerComposeScriptPath: $dynamiDockerComposeScriptPath"
		# Launch Dynamic Docker Compose script located in package
        & $dynamiDockerComposeScriptPath -launcherScriptDirectory $launcherScriptDirectory -envFileName $envFileName -template $template -up:$up -down:$down -list:$list

    } else {
        Write-Host "Settings not found with name $projectName. Please specify your project name (You can check your settings here : $projectSettingsPath)" -ForegroundColor Red
    }    
} else {
    Write-Host "Settings not found at $projectSettingsPath" -ForegroundColor Red
}


Set-Location -LiteralPath $currentDirectory
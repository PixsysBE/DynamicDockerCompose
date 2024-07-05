param (
    [Alias("env-name")]
    [string]$envFileName,
    [switch]$up=$false,
    [switch]$down=$false,
    [string]$rootPath,
    [string]$dockerComposeYamlPath,
    [string]$dockerFilePath,
    [string]$csprojPath,
    [string]$slnPath,
    [string]$entrypointScriptPath,
    [switch]$verbose
)

$ErrorActionPreference = 'Stop'

if((-not $up.IsPresent) -and (-not $down.IsPresent))
{
  Write-Host "Mode not selected, please use -up or -down"  
  exit 1
}

if ([string]::IsNullOrWhiteSpace($envFileName)) {
	$envFileName = Read-Host -Prompt "Please enter the .env file name located in your .config folder (ex.: docker-dev)" 
}

# Import functions
$functionsPath = Join-Path -Path $PSScriptRoot -ChildPath "./dynamic-docker-compose.functions.ps1"
. $functionsPath

# Get env file path
$envFilePath = Join-Path -Path $PSScriptRoot -ChildPath "../../.config/${envFileName}.env"
if((Test-Path -Path $envFilePath) -eq $false)
{
    Write-Host "env file not found. Please make sure it is located in your .config folder"
    exit 1
}
$envFilePath = Resolve-Path $envFilePath 

if($down.IsPresent){
    docker-compose --env-file ${envFilePath} down
    exit 0
}

# Get env file content
$envFileContent = Get-Content -Path $envFilePath
# Get Root path
if ([string]::IsNullOrWhiteSpace($rootPath)) {
    $rootPath = Get-EnvValue -content $envFileContent -variableName "ROOT_PATH" -verbose:$verbose
    if ([string]::IsNullOrWhiteSpace($rootPath)) {
        # Define root path from script location
        $rootPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "../../../")
    }
}

# Set Environment variables
$env:solutionName = Get-EnvValue -content $envFileContent -variableName "SOLUTION_NAME"
$env:rootAbsolutePath = Use-Absolute-Path -path $rootPath
Write-Host-Verbose "rootAbsolutePath:" $env:rootAbsolutePath
$env:dockerFilePath = Get-Relative-Path-From-Root-Absolute-Path -name "dockerFilePath" -paramValue $dockerFilePath -envFileContent $envFileContent -envVariableName "DOCKER_FILE_PATH" -defaultPath "./**/.build/Dockerfile" -verbose:$verbose
Write-Host-Verbose "dockerFilePath:" $env:dockerFilePath
$env:csprojPath = Get-Relative-Path-From-Root-Absolute-Path -name "csprojPath" -paramValue $csprojPath -envFileContent $envFileContent -envVariableName "CSPROJ_PATH" -defaultPath "./**/*.csproj" -excludePattern ".Tests.csproj" -verbose:$verbose
Write-Host-Verbose "csprojPath:" $env:csprojPath
$env:slnPath = Get-Relative-Path-From-Root-Absolute-Path -name "slnPath" -paramValue $slnPath -envFileContent $envFileContent -envVariableName "SLN_PATH" -defaultPath "./*.sln" -verbose:$verbose
Write-Host-Verbose "slnPath:" $env:slnPath
$env:entrypointScriptPath = Get-Relative-Path-From-Root-Absolute-Path -name "entrypointScriptPath" -paramValue $entrypointScriptPath -envFileContent $envFileContent -envVariableName "ENTRYPOINT_SCRIPT_PATH" -defaultPath "./**/.build/DynamicDockerCompose/Scripts/entrypoint.sh" -verbose:$verbose
Write-Host-Verbose "entrypointScriptPath:" $env:entrypointScriptPath
$dockerComposeYamlPath = Get-Relative-Path-From-Root-Absolute-Path -name "dockerComposeYamlPath" -paramValue $dockerComposeYamlPath -envFileContent $envFileContent -envVariableName "DOCKER_COMPOSE_YAML_PATH" -defaultPath "./**/.build/docker-compose.yaml" -verbose:$verbose

# Run Docker compose
docker-compose --env-file $envFilePath -f $dockerComposeYamlPath up --build
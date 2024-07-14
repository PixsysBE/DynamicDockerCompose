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
$env:rootAbsolutePath = Use-Absolute-Path -path $rootPath
Write-Host -ForegroundColor Green "rootAbsolutePath:" $env:rootAbsolutePath
$env:slnPath = Get-Variable-Absolute-Path -variableName "slnPath" -paramValue $slnPath -envFileContent $envFileContent -envVariableName "SLN_PATH" -filter "*.sln" -verbose:$verbose
$env:solutionName = Split-Path -Path $env:slnPath -Parent | Split-Path -Leaf
$env:slnPath = Get-Relative-Path-From-Absolute-Path -absolutePath $env:slnPath -fromAbsolutePath $env:rootAbsolutePath -verbose:$verbose
Write-Host -ForegroundColor Green "slnPath:" $env:slnPath
Write-Host -ForegroundColor Green "solutionName:" $env:solutionName
$env:dockerFilePath = $(Get-Variable-Absolute-Path -variableName "dockerFilePath" -paramValue $slnPath -envFileContent $envFileContent -envVariableName "DOCKER_FILE_PATH" -filter "Dockerfile" -Directory ".build" -verbose:$verbose) | 
                      ForEach-Object { Get-Relative-Path-From-Absolute-Path -absolutePath $_ -fromAbsolutePath $env:rootAbsolutePath -verbose:$verbose }
Write-Host -ForegroundColor Green "dockerFilePath:" $env:dockerFilePath
$env:csprojPath = $(Get-Variable-Absolute-Path -variableName "csprojPath" -paramValue $csprojPath -envFileContent $envFileContent -envVariableName "CSPROJ_PATH" -filter "*.csproj" -verbose:$verbose -excludePattern ".Tests.csproj") | 
                  ForEach-Object { Get-Relative-Path-From-Absolute-Path -absolutePath $_ -fromAbsolutePath $env:rootAbsolutePath -verbose:$verbose }
Write-Host -ForegroundColor Green "csprojPath:" $env:csprojPath
$env:entrypointScriptPath = $(Get-Variable-Absolute-Path -variableName "entrypointScriptPath" -paramValue $entrypointScriptPath -envFileContent $envFileContent -envVariableName "ENTRYPOINT_SCRIPT_PATH" -filter "entrypoint.sh" -Directory "./**/.build/DynamicDockerCompose/Scripts" -verbose:$verbose) | 
                            ForEach-Object { Get-Relative-Path-From-Absolute-Path -absolutePath $_ -fromAbsolutePath $env:rootAbsolutePath -verbose:$verbose }
Write-Host -ForegroundColor Green "entrypointScriptPath:" $env:entrypointScriptPath 
$dockerComposeYamlPath = Get-Variable-Absolute-Path -variableName "dockerComposeYamlPath" -paramValue $dockerComposeYamlPath -envFileContent $envFileContent -envVariableName "DOCKER_COMPOSE_YAML_PATH" -filter "docker-compose.yaml" -Directory "./**/.build" -verbose:$verbose
Write-Host -ForegroundColor Green "dockerComposeYamlPath:" $dockerComposeYamlPath

# Run Docker compose
docker-compose --env-file $envFilePath -f $dockerComposeYamlPath up --build
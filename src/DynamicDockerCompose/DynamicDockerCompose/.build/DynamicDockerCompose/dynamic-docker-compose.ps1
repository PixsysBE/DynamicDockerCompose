[CmdletBinding()]
param (
    [string]$launcherScriptDirectory=$PSScriptRoot, # Directory containing launcher
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

if((-not $up.IsPresent) -and (-not $down.IsPresent) -and (-not $list.IsPresent))
{
  Write-Host "Mode not selected, please use -up, -down or -list"  
  exit 1
}


# Directory containing dynamic-docker-compose.ps1
$dynamicDockerComposeScriptDirectory = $PSScriptRoot

# Import functions
$functionsPath = Join-Path -Path $dynamicDockerComposeScriptDirectory -ChildPath "./dynamic-docker-compose.functions.ps1"
. $functionsPath

# Get env file path
if (-not [string]::IsNullOrWhiteSpace($envFileName)) {
    $envFilePath = Join-Path -Path $launcherScriptDirectory -ChildPath "../../.config/${envFileName}.env"
    if((Test-Path -Path $envFilePath) -eq $false)
    {
        Write-Host "env file not found. Please make sure it is located in your .config folder"
        exit 1
    }
    $envFilePath = Resolve-Path $envFilePath 
}

if($down.IsPresent){
    if (-not [string]::IsNullOrWhiteSpace($envFilePath)) {
    docker-compose --env-file $envFilePath down
    } else {
        docker-compose down
    }
    exit 0
}

$variables = @()
$envFileContent = $null

Get-Dynamic-Parameters -remainingArgs $remainingArgs -collection ([ref]$variables)
if (-not [string]::IsNullOrWhiteSpace($envFilePath)) {
    Get-Env-File-Variables -filepath $envFilePath -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)
}

# Get Root path
if ([string]::IsNullOrWhiteSpace($rootPath)) {
    $rootPath = Get-Env-Variable-Value -content $envFileContent -variableName "ROOT_PATH"
    if ([string]::IsNullOrWhiteSpace($rootPath)) {
        # Define root path from script location
        $rootPath = Resolve-Path (Join-Path -Path $launcherScriptDirectory -ChildPath "../../../")
    }
}
$env:rootAbsolutePath = Use-Absolute-Path -path $rootPath
Add-Variable-To-Collection -name "ROOT_ABSOLUTE_PATH" -value $env:rootAbsolutePath -collection ([ref]$variables)

# Get Docker compose yaml variables
$dockerComposeYamlVariableName = "dockerComposeYamlPath"
$(Get-Variable-Absolute-Path -variableName $dockerComposeYamlVariableName -filter "docker-compose.yaml" -searchFromPath $env:rootAbsolutePath -Directory "./**/.config" -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)) | ForEach-Object{ Add-Variable-To-Collection -name $dockerComposeYamlVariableName -value $_ -collection ([ref]$variables) } 
$dockerComposeYamlPathExists = $variables | Where-Object {$_.name -eq $dockerComposeYamlVariableName}
if($dockerComposeYamlPathExists){
    Get-Docker-Compose-Variables -filepath $dockerComposeYamlPathExists.value -collection ([ref]$variables)
}

if($template -eq "dotnet-webapp")
{
    # Get dotnet-webapp variables
    $slnPath = Get-Variable-Absolute-Path -variableName "SLN_PATH" -paramValue $slnPath -filter "*.sln" -searchFromPath $env:rootAbsolutePath -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)
    Add-Variable-To-Collection -name "SOLUTION_NAME" -value (Split-Path -Path $slnPath -Parent | Split-Path -Leaf) -collection ([ref]$variables)  
    Add-Variable-To-Collection -name "SLN_PATH" -value ( Get-Relative-Path-From-Absolute-Path -fromPath $env:rootAbsolutePath -toPath $slnPath) -collection ([ref]$variables)  
    $dockerFilePath = Get-Variable-Absolute-Path -variableName "DOCKER_FILE_PATH" -filter "Dockerfile" -searchFromPath $env:rootAbsolutePath -Directory ".config" -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)
    Add-Variable-To-Collection -name "DOCKER_FILE_PATH" -value ( Get-Relative-Path-From-Absolute-Path -fromPath $env:rootAbsolutePath -toPath $dockerFilePath) -collection ([ref]$variables)  
    $csprojPath = Get-Variable-Absolute-Path -variableName "CSPROJ_PATH" -filter "*.csproj" -searchFromPath $env:rootAbsolutePath -excludePattern ".Tests.csproj" 
    Add-Variable-To-Collection -name "CSPROJ_PATH" -value ( Get-Relative-Path-From-Absolute-Path -fromPath $env:rootAbsolutePath -toPath $csprojPath) -collection ([ref]$variables)  
    $entrypointScriptPath = Get-Variable-Absolute-Path -variableName "ENTRYPOINT_SCRIPT_PATH" -filter "entrypoint.sh" -searchFromPath $env:rootAbsolutePath -Directory "**/.build/DynamicDockerCompose/Scripts" -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)
    # Add-Variable-To-Collection -name "ENTRYPOINT_SCRIPT_PATH" -value $entrypointScriptPath -collection ([ref]$variables)  
    Add-Variable-To-Collection -name "ENTRYPOINT_SCRIPT_PATH" -value (  Get-Relative-Path-From-Absolute-Path -fromPath $env:rootAbsolutePath -toPath $entrypointScriptPath) -collection ([ref]$variables)  
    $secretstorePasswordPath = Get-Variable-Absolute-Path -variableName "secretstore_password_path" -searchFromPath $env:rootAbsolutePath -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)
    Add-Variable-To-Collection -name "secretstore_password_path" -value $secretstorePasswordPath -collection ([ref]$variables)  
    $secretstoreVaultName = Get-Variable-Absolute-Path -variableName "secretstore_vault_name" -searchFromPath $env:rootAbsolutePath -collection ([ref]$variables) -envFileContent ([ref]$envFileContent)
    Add-Variable-To-Collection -name "secretstore_vault_name" -value $secretstoreVaultName -collection ([ref]$variables)  
    if ((-not [string]::IsNullOrWhiteSpace($secretstorePasswordPath)) -and (-not [string]::IsNullOrWhiteSpace($secretstorePasswordPath))) {
        # Unlock secret store to get secrets
        $secretstorePassword = Import-CliXml -Path $secretstorePasswordPath
        Unlock-SecretStore -Password $secretstorePassword
        Add-Variable-To-Collection -name CERTIFICATE_PATH -value (Get-Secret -Name CERTIFICATE_PATH -Vault $secretstoreVaultName -AsPlainText) -collection ([ref]$variables)  
        Add-Variable-To-Collection -name CERTIFICATE_PASSWORD -value (Get-Secret -Name CERTIFICATE_PASSWORD -Vault $secretstoreVaultName -AsPlainText) -collection ([ref]$variables)  
    }
}

if($list.IsPresent){ 
    Write-Output $variables | Sort-Object Name
    exit 0 
}    

Set-Environment-Variables -collection ([ref]$variables)

# Run Docker compose
if (-not [string]::IsNullOrWhiteSpace($envFilePath)) {
    docker-compose --env-file $envFilePath -f $dockerComposeYamlPathExists.value up --build
} else {
    docker-compose -f $dockerComposeYamlPathExists.value up --build
}
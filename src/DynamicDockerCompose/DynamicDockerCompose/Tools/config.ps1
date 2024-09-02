[CmdletBinding()]
param($MSBuildThisFileDirectory, # The package build folder
$MSBuildProjectDirectory, # The project Directory
$MSBuildProjectName, # The project Name
$MSBuildProjectFile) # The project File Name (.csproj)

# Write-Host "MSBuildThisFileDirectory: $MSBuildThisFileDirectory"
# Write-Host "MSBuildProjectDirectory: $MSBuildProjectDirectory"
# Write-Host "MSBuildProjectName: $MSBuildProjectName"
# Write-Host "MSBuildProjectFile: $MSBuildProjectFile"

function Update-Config-JsonFile {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$NewObject,   # L'objet à ajouter ou modifier dans le fichier JSON

        [Parameter(Mandatory=$true)]
        [string]$FilePath        # Chemin du fichier JSON à modifier
    )

    $objectList = @()

    if (Test-Path -Path $FilePath) {
        try {
            $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
            $objectList = @($jsonContent)
        } catch {
            Write-Host "Error while reading JSON file: $_"
            return
        }
    }
    $existingObject = $objectList | Where-Object { $_.Name -eq $NewObject.Name }
    if ($existingObject) {
        foreach ($property in $NewObject.Keys) {
            $existingObject.$property = $NewObject.$property
        }
    } else {
        $objectList += [PSCustomObject]$NewObject
    }
    $json = $objectList | ConvertTo-Json -Depth 10 #-Compress
    try {
        $json | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Verbose "JSON file successfully updated at location: $FilePath"
    } catch {
        Write-Host "Error while saving JSON file: $_"
    }
}

$packageDirectory = (Join-Path -Path $MSBuildThisFileDirectory -ChildPath "..") | Resolve-Path

# Adding current project configuration in DynamicDockerCompose.settings.json
$projectSettings = @{
    "Name" = "$MSBuildProjectName"
    "ProjectDirectory" = "$MSBuildProjectDirectory"
    "PackageDirectory" = "$packageDirectory"
    "VersionNumber" = "$(Split-Path $packageDirectory -Leaf)"
}

$dynamicDockerComposeSettingsPath = Join-Path -Path $MSBuildProjectDirectory -ChildPath "../.config/DynamicDockerCompose.settings.json"
Write-Verbose "dynamicDockerComposeSettingsPath: $dynamicDockerComposeSettingsPath"
Write-Verbose "projectSettings: $($projectSettings)"

Update-Config-JsonFile -NewObject $projectSettings -FilePath $dynamicDockerComposeSettingsPath

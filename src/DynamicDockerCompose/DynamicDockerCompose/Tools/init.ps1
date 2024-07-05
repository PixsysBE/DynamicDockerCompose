param($installPath, $toolsPath, $package, $project)

function Copy-New-Item {
    param (
        [string]$Path,
        [string]$Destination      
    )
  
    If (-not (Test-Path $Destination)) {
      New-Item -ItemType File -Path $Destination -Force
    } 
    Copy-Item -Path $Path -Destination $Destination
  }

# Get the current directory
$currentDirectory = Get-Location

##### .build folder #####
$overrideFiles = @("\DynamicDockerCompose\dynamic-docker-compose.functions.ps1",
                   "\DynamicDockerCompose\dynamic-docker-compose.ps1",
                   "\DynamicDockerCompose\Scripts\entrypoint.sh"
                  )

$sourceBuildPath = Join-Path -Path $installPath -ChildPath "/.build"
$targetBuildPath = Join-Path -Path $currentDirectory -ChildPath "/.build"
$sourceBuildFiles = Get-ChildItem -Path $sourceBuildPath -File -Recurse
foreach($sourceBuildFile in $sourceBuildFiles)
{
    $sourceRelativePath = $sourceBuildFile.FullName.Remove(0,($sourceBuildPath.length))
    $targetPath = Join-Path -Path $targetBuildPath -ChildPath $sourceRelativePath
    $exists = Test-Path -Path $targetPath
    # Write-Host $sourceBuildFile.FullName
    if($exists -eq $true){
        if($overrideFiles -contains $sourceRelativePath)
        {
            Write-Host "${sourceRelativePath} already exists but will be overriden"  -ForegroundColor Green
            Copy-Item -Path $sourceBuildFile.FullName -Destination $targetPath -Force
        } else {
            Write-Host "${sourceRelativePath} already exists, skipping..."  -ForegroundColor Red -BackgroundColor Yellow
        }
    }
    else {
        Write-Host "Copying ${targetPath}..."  
        Copy-New-Item -Path $sourceBuildFile.FullName -Destination $targetPath -Recurse -Force
    }
    # Write-Host $targetPath $exists #sourceRelativePath
}

##### .config folder #####

$targetConfigPath = Join-Path -Path $currentDirectory -ChildPath "/.config/"

$copyConfigFiles = -not (Test-Path -Path $targetConfigPath)
if($copyConfigFiles -eq $false)
{
    $targetConfigFilesCount = (Get-ChildItem -Path $targetConfigPath -Filter "*.env").Count
    if($targetConfigFilesCount -gt 0)
    {
        Write-Host "Env files already found, skipping..." -ForegroundColor Red -BackgroundColor Yellow
    }
    else {
        $copyConfigFiles=$true
    }
}

if($copyConfigFiles -eq $true) {
    Write-Host "Copying .config folder..."
    $sourceConfigPath = Join-Path -Path $installPath -ChildPath "/.config/"
    Copy-Item -Path $sourceConfigPath -Destination $currentDirectory -Recurse
}
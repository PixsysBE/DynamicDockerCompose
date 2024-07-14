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
$overrideFiles = @(".build\DynamicDockerCompose\dynamic-docker-compose.functions.ps1",
                   ".build\DynamicDockerCompose\dynamic-docker-compose.ps1",
                   ".build\DynamicDockerCompose\Scripts\entrypoint.sh",
                   ".config\docker-dev.sample.env"
                  )

# Copy folder files
$folders = @(".build",".config")
foreach($folder in $folders)
{
    $sourcePath = Join-Path -Path $installPath -ChildPath $folder
    $targetBasePath = Join-Path -Path $currentDirectory -ChildPath $folder
    $sourceFiles = Get-ChildItem -Path $sourcePath -File -Recurse
    foreach($sourceFile in $sourceFiles)
    {
        $sourceRelativePath = $sourceFile.FullName.Remove(0,($sourcePath.length))
        $targetPath = Join-Path -Path $targetBasePath -ChildPath $sourceRelativePath
        # Write-Host $sourceFile.FullName
        if(Test-Path -Path $targetPath){
            if($overrideFiles -contains ($folder + $sourceRelativePath))
            {
                Write-Host "${sourceRelativePath} already exists but will be overriden"  -ForegroundColor Green
                Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force
            } else {
                Write-Host "${sourceRelativePath} already exists, skipping..."  -ForegroundColor Red -BackgroundColor Yellow
            }
        }
        else {
            Write-Host "Copying ${targetPath}..."  
            Copy-New-Item -Path $sourceFile.FullName -Destination $targetPath -Recurse -Force
        }
    }
}
# Ensures the path will be absolute
function Use-Absolute-Path {
        param (
            [string]$path        
        )

    if([System.IO.Path]::IsPathRooted($path))
    {
        # Ensures that the last character on the extraction path is the directory separator char.
        if(-not $path.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString(), [StringComparison]::Ordinal)){
            $path += [System.IO.Path]::DirectorySeparatorChar;
        }
        return $path
    }
    else 
    {
        return Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath $path)
    }
}

# Gets value from the .env file
function Get-EnvValue {

    param (
        $content,
        [string]$variableName,
        [switch]$verbose
    )

   if($verbose.IsPresent){ 
        Write-Host "[Get-EnvValue] Checking if variable ${variableName} is found in .env file" 
        #Write-host $content  
   }
   $content -match "^$variableName=" | ForEach-Object {
   if($verbose.IsPresent){ 
        Write-host "[Get-EnvValue] match:" $_  
    }
        $variable = $_ -split "="
        $returnValue = $variable[1]
        if ($returnValue -match "#") {
            $variable = $returnValue -split "#"
            $returnValue = $variable[0].Trim()
        }
    }

    if($verbose.IsPresent){ 
        Write-host "[Get-EnvValue] returnValue: " $returnValue
    }

    return $returnValue
}

# Write-Host if verbose is present
function Write-Host-Verbose{
    if($verbose.IsPresent){
        for ( $i = 0; $i -lt $args.count; $i++ ) {
            if($i -eq ($args.count-1)){
                write-host "" $args[$i]
            }else{
                write-host "" $args[$i] -NoNewline
            }
        } 
    }
}

# Gets the relative path from the root absolute path
function Get-Relative-Path-From-Root-Absolute-Path {

    param (
        [string]$paramValue,
        [string]$name,
        $envFileContent,
        [string]$envVariableName,
        [string]$defaultPath,
        [string]$excludePattern = $null,
        [switch]$verbose
    )

   # Check if path is passed as parameter
   if($verbose.IsPresent){ 
        Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] Checking variable ${name}..."
        Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] Checking if variable value is passed as parameter..." 
    }
   if (-not [string]::IsNullOrWhiteSpace($paramValue)) { 
       return $paramValue
   }

   # Check if path is in .env file
   if($verbose.IsPresent){ 
        Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] Checking if variable ${envVariableName} is found in .env file" 
   }

   $envValue = Get-EnvValue -content $envFileContent -variableName $envVariableName -verbose:$verbose
   
   if($verbose.IsPresent){ 
        Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] envValue: " $envValue
   }
   if (-not [string]::IsNullOrWhiteSpace($envValue)) { 
       return $envValue
   }

   # Get relative path from root
   if($verbose.IsPresent){ 
    Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] Get relative path from root for ${name}" -ForegroundColor Blue 
    Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] env:rootAbsolutePath" $env:rootAbsolutePath
    Write-Host "[Get-Relative-Path-From-Root-Absolute-Path] defaultPath" $defaultPath
    }
   $path = Join-Path -Path $env:rootAbsolutePath -ChildPath $defaultPath
   $absolutePath = Resolve-Path -Path $path
   if ($absolutePath.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($excludePattern) ) {
       $filteredPaths = $absolutePath | Where-Object { -not $_.Path.Contains($excludePattern) }
        $filteredPathsCount = $filteredPaths.Count
        if ($filteredPathsCount -eq 1) {
            $absolutePath = $filteredPaths[0]
        } else {
            Write-Output "[Get-Relative-Path-From-Root-Absolute-Path] Error : ${name} : ${filteredPathsCount} match(es) found after filtering."
            exit 1
        }
    } 
    $absolutePath = $absolutePath -replace [regex]::Escape($env:rootAbsolutePath), '' -replace '\\', '/'
    if ($absolutePath.StartsWith("/")) { $absolutePath = $absolutePath.Substring(1) }

    return "./" + $absolutePath
}


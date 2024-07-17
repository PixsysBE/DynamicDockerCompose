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
    [string]$variableName
)

Write-Verbose ("[Get-EnvValue] Checking if variable ${variableName} is found in .env file") 
$content -match "^$variableName=" | ForEach-Object {
    Write-Verbose ("[Get-EnvValue] match: $_") 
    $variable = $_ -split "="
    $returnValue = $variable[1]
    if ($returnValue -match "#") {
        $variable = $returnValue -split "#"
        $returnValue = $variable[0].Trim()
    }
}

Write-Verbose ("[Get-EnvValue] returnValue: $returnValue")
return $returnValue
}

# Get variable absolute path, looking in different places
function Get-Variable-Absolute-Path {
param (
    [string]$variableName,
    # [string]$variableValue,
    [ref]$envFileContent,
    [ref]$collection,
    # [string]$envVariableName,
    [string]$filter,
    [string]$directory,
    [string]$excludePattern = $null
    # [switch]$verbose
)
Write-Verbose ("[Get-Variable-Absolute-Path] Checking variable ${variableName}...")
Write-Verbose ("[Get-Variable-Absolute-Path] Checking if variable value is passed as parameter...")

# Check if path is passed as parameter
$parameterExists = $collection.Value | Where-Object {$_.name -eq $variableName}
if($parameterExists){
    if (-not [string]::IsNullOrWhiteSpace($parameterExists.value)) { 
        # Add-Variable-To-Collection -name $variableName -value $parameterExists.value -collection $collection
        return $parameterExists.value
    }
}

# Check if path is in .env file
$envValue = Get-EnvValue -content $envFileContent -variableName $variableName -verbose:$verbose
if (-not [string]::IsNullOrWhiteSpace($envValue)) { 
    # Add-Variable-To-Collection -name $variableName -value $envValue -collection $collection
    return $envValue
}
Write-Verbose ("[Get-Variable-Absolute-Path] Searching from path: $env:rootAbsolutePath")
Write-Verbose ("[Get-Variable-Absolute-Path] filter: $filter")
if (-not [string]::IsNullOrWhiteSpace($directory)) { 
    Write-Verbose ("[Get-Variable-Absolute-Path] directory: $directory")
    if($directory -like "*/*"){
        $directory = Join-Path -Path $env:rootAbsolutePath -ChildPath $directory | Resolve-Path
        $items = @(Get-ChildItem -Path $directory | Where-Object { $_.FullName.Contains($filter)} | Select-Object FullName)
    } else {
        $items = Get-ChildItem -Path $env:rootAbsolutePath -Recurse -Directory -Filter $directory  | 
        ForEach-Object { Get-ChildItem -Path $_.FullName -Filter $filter | Select-Object FullName }
    }
} else {
    $items = Get-ChildItem -Path $env:rootAbsolutePath -Recurse -Filter $filter  
}
if ($items.Count -gt 1) {
    if(-not [string]::IsNullOrWhiteSpace($excludePattern) )
    {
        $items = $items | Where-Object { -not $_.FullName.Contains($excludePattern) }
        if ($items.Count -eq 1) {
            # Add-Variable-To-Collection -name $variableName -value $items[0].FullName -collection $collection
           return $items[0].FullName
        }
    }
    if ($items.Count -gt 1) {
         Write-Host "[Get-Absolute-Path] Error when checking variable ${variableName} : $($items.Count) match(es) found after filtering." -ForegroundColor Red
         exit 1
     }
 }elseif($items.Count -eq 0) {
    Write-Host "[Get-Absolute-Path] No value has been found for variable $variableName with filter $filter" -ForegroundColor Red
    exit 1
 }
#  Add-Variable-To-Collection -name $variableName -value $items[0].FullName -collection $collection
 return $items[0].FullName
}

# Get relative path from an absolute path
function Get-Relative-Path-From-Absolute-Path {
param (
    [string]$absolutePath,
    [string]$fromAbsolutePath
)
Write-Verbose ("[Get-Relative-Path-From-Absolute-Path] absolutePath: $absolutePath")
Write-Verbose ("[Get-Relative-Path-From-Absolute-Path] fromAbsolutePath: $fromAbsolutePath") 
$relativePath = $absolutePath -replace [regex]::Escape($fromAbsolutePath), '' -replace '\\', '/'
if ($relativePath.StartsWith("/")) { $relativePath = $relativePath.Substring(1) }
return $relativePath
}


function Get-Dynamic-Parameters {
    param (
      [ref]$collection,
      [string[]]$remainingArgs,
      [switch]$verbose
    )
    $i=0
    while($i -lt $remainingArgs.Length){
      $key = $remainingArgs[$i].Substring(2)
      # Write-Output "key: $key"
  
      if($i + 1 -lt $remainingArgs.Length -and $remainingArgs[$i + 1] -notmatch '^--[\w]+'){
        $value = $remainingArgs[$i + 1]
        #$collection[$key] = $value
        Add-Variable-To-Collection -name $key -value $value -location "parameter" -collection $collection
        $i += 2
      } else {
        #$collection[$key] = $true
        Add-Variable-To-Collection -name $key -value $true -location "parameter" -type "switch" -collection $collection
        $i += 1
      }
    }
  }
  
  function Get-Env-File-Variables {
  <#
      .SYNOPSIS
      Get-Env-File-Values
      .DESCRIPTION
      Get-Env-File-Values description
  #>
    param (
        [ref]$collection,
        [ref]$envFileContent,
        [string]$filepath
    )
    Write-Verbose "[Get-Env-File-Variables]"
    # $filePath = Join-Path -Path $PSScriptRoot -ChildPath $path
    if(Test-Path $filePath){
        $envFileContent.Value = Get-Content -Path $filePath
        $envFileContent.Value -match "=" | ForEach-Object {
        $variable = $_ -split "="
        $key = $variable[0].Trim()
        # if($variables -notcontains $key){
          $value = $variable[1].Trim()
          if ($value -match "#") {
            $splitValue = $value -split "#"
            $value = $splitValue[0].Trim()
          }
          Add-Variable-To-Collection -name $key -value $value -location "env" -collection $collection
          # $variables[$key] = $value
        # }
      }
    }
    else{
      Write-Host "env file not found" -ForegroundColor Red
      exit 1
    }
  }
  
  function Get-Docker-Compose-Variables{
    param (
        [ref]$collection,
        [string]$filePath
        # [switch]$verbose
    )
    Write-Verbose ("[Get-Docker-Compose-Variables]")
    # $filePath = Join-Path -Path $PSScriptRoot -ChildPath $path
    if(Test-Path $filePath){
      $content = Get-Content -Path $filePath -Raw
      $regex = '\$\{(.*?)\}'
      $regexMatches = [regex]::Matches($content, $regex)
      foreach($match in $regexMatches)
      {
        Add-Variable-To-Collection -name $match.Groups[1].Value -value "" -location "yaml" -collection $collection
      }
    }
    else{
      Write-Host "yaml file not found" -ForegroundColor Red
      exit 1
    }
  }
  
  function Add-Variable-To-Collection{
    param(
      [string]$name,
      $value,
      [string]$type = "string",
      [string]$location,
      [ref]$collection
    )
    # Write-Host "Add-Variable-To-Collection" $name
    $exists = $collection.Value | Where-Object {$_.name -eq $name}
  
    if(-not $exists){
      $collection.Value += [PSCustomObject]@{ name = $name; value = $value; type=$type; location = $location  }
    }
    else {
      $exists | ForEach-Object {
        if((-not [string]::IsNullOrWhiteSpace($location)) -and ($_.location -notmatch $location)){
            if([string]::IsNullOrWhiteSpace($_.location)){
                $_.location = $location
            }else {
                $_.location += ", $location"
            }
        }
        if([string]::IsNullOrWhiteSpace($_.value) ){
            $_.value = $value
        }
      }
    }
  }

  function Set-Environment-Variables {
    param (
        [ref]$collection
    )

    $collection.Value | Sort-Object Name | ForEach-Object {
        if((-not [string]::IsNullOrWhiteSpace($_.value)) -and ($_.name -cmatch "^[A-Z_]*$" ) ){
            Write-Verbose "setting environment variable $($_.name) with value $($_.value)"
            Set-Item "env:$($_.name)" $_.value 
        }
    }
  }
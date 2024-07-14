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
function Write-Host-Verbose {
param (
    [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White,
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$Text
)

if ($verbose.IsPresent) {
    [Console]::ForegroundColor = $ForegroundColor

    for ($i = 0; $i -lt $Text.Count; $i++) {
        if ($i -eq ($Text.Count - 1)) {
            Write-Host "" $Text[$i]
        } else {
            Write-Host "" $Text[$i] -NoNewline
        }
    }
    [Console]::ResetColor()
}
}

# Get variable absolute path, looking in different places
function Get-Variable-Absolute-Path {
param (
    [string]$variableName,
    [string]$variableValue,
    $envFileContent,
    [string]$envVariableName,
    [string]$filter,
    [string]$directory,
    [string]$excludePattern = $null,
    [switch]$verbose
)
Write-Host-Verbose -ForegroundColor Blue "[Get-Absolute-Path] Checking variable ${variableName}..."
Write-Host-Verbose -ForegroundColor White "[Get-Absolute-Path] Checking if variable value is passed as parameter..." 

# Check if path is passed as parameter
if (-not [string]::IsNullOrWhiteSpace($variableValue)) { 
    return $variableValue
}

# Check if path is in .env file
$envValue = Get-EnvValue -content $envFileContent -variableName $envVariableName -verbose:$verbose
if (-not [string]::IsNullOrWhiteSpace($envValue)) { 
    return $envValue
}
Write-Host-Verbose -ForegroundColor White "[Get-Absolute-Path] Searching from path:" $env:rootAbsolutePath
Write-Host-Verbose -ForegroundColor White "[Get-Absolute-Path] filter:" $filter
if (-not [string]::IsNullOrWhiteSpace($directory)) { 
    Write-Host-Verbose -ForegroundColor White "[Get-Absolute-Path] directory:" $directory
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
           return $items[0].FullName
        }
    }
    if ($items.Count -gt 1) {
         Write-Host "[Get-Absolute-Path] Error when checking variable ${variableName} : $($items.Count) match(es) found after filtering." -ForegroundColor Red
         exit 1
     }
 } 
 return $items[0].FullName
}

# Get relative path from an absolute path
function Get-Relative-Path-From-Absolute-Path {
param (
    [string]$absolutePath,
    [string]$fromAbsolutePath,
    [switch]$verbose
)
Write-Host-Verbose -ForegroundColor White "[Get-Relative-Path-From-Absolute-Path] absolutePath: " $absolutePath
Write-Host-Verbose -ForegroundColor White "[Get-Relative-Path-From-Absolute-Path] fromAbsolutePath: " $fromAbsolutePath
$relativePath = $absolutePath -replace [regex]::Escape($fromAbsolutePath), '' -replace '\\', '/'
if ($relativePath.StartsWith("/")) { $relativePath = $relativePath.Substring(1) }
return $relativePath
}

<#
.SYNOPSIS
Ensure csproj has all the properties needed
#>
function Confirm-csproj-properties{
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath
    )

    $ErrorActionPreference = 'Stop'   

    if((Test-Path -Path $csprojPath) -eq $false){
        Write-Host "[Confirm-csproj-properties] Path $csprojPath does not exist" -foregroundColor Red
        exit 1
    }
    Write-Verbose ("[Confirm-csproj-properties] csprojPath: $($csprojPath)")

    # Get csproj
    $csproj = Get-Item -Path $csprojPath
    # Load the XML content of the csproj file
    $xml = [xml](Get-Content $csproj.FullName)
    # Potential missing properties that does not require user input
    $noInputProperties = @(
        @{
            xmlProperty = $xml.Project.PropertyGroup.IsPackable
            name = "IsPackable"
            value = "true"
        }
    )

    $propertyGroup = $xml.Project.PropertyGroup
    $saveFile = $false
    foreach ($row in $noInputProperties) {
        if ($null -eq $row.xmlProperty) {
        $propertyElement = $xml.CreateElement($row.name)
        $propertyElement.InnerText = $row.value
        $propertyGroup.AppendChild($propertyElement)
        $saveFile = $true
        }
    }

    Save-File -filePath $filePath -saveFile $saveFile

    if($saveFile -eq $false)
    {
        Write-Host "All required properties exist in $($csproj.Name)"  
    }
}

<#
.SYNOPSIS
Ensure package.json has all the properties needed
#>
function Confirm-Package-Json-Properties {
    param (
        [string]$filePath,
        [string]$packageId
    )

    Write-Verbose ("[Confirm-Package-Json-Properties] Checking package.json path: $filePath")
    # Check if the file exists
    if (Test-Path $filePath) {
        # Read the content of the file
        $jsonContent = Get-Content $filePath -Raw | ConvertFrom-Json
        $saveFile=$false
        # Check if the "name" property exist
        if (-not $jsonContent.name) {
            # Add the "name" property 
            $jsonContent | Add-Member -MemberType NoteProperty -Name "name" -Value $packageId.ToLower() -Force
            $saveFile = $true
        }
        if (-not $jsonContent.private) {
            # Allow running without an configured NPM_TOKEN : https://github.com/semantic-release/npm/issues/324
            $jsonContent | Add-Member -MemberType NoteProperty -Name "private" -Value $true -Force
            $saveFile = $true
        }
                
        if($saveFile -eq $true){                
            # Convert the JSON object back to JSON format
            $newContent = $jsonContent | ConvertTo-Json -Depth 2
            # Write the new content to the file
            $newContent | Set-Content $filePath
            Write-Host  "One or more properties have been successfully added to package.json"
        }

        $changelogVersion = $jsonContent.dependencies.'@semantic-release/changelog'.Substring(1)
        $execVersion = $jsonContent.dependencies.'@semantic-release/exec'.Substring(1)
        $gitVersion = $jsonContent.dependencies.'@semantic-release/git'.Substring(1)
        $semanticReleaseVersion = $jsonContent.dependencies.'semantic-release'.Substring(1)

        return [PSCustomObject]@{
            changelogVersion = $changelogVersion
            execVersion = $execVersion
            gitVersion = $gitVersion
            semanticReleaseVersion = $semanticReleaseVersion
        }
            
    } else {
        Write-Host "The file package.json doesn't exist."
        exit 1
    }
}

<#
.SYNOPSIS
Copy Git Hooks
#>
function Copy-Git-Hooks {
    param (
        [string]$filePath,
        [string]$includePath,
        [string]$destinationFolder
    )
    Write-Verbose ("[Copy-Git-Hooks] Copying Git Hooks...")
    $xml = [xml](Get-Content $filePath)
    $saveFile = $false

    $target = $xml.Project.Target
    if ($null -eq $target) {
        $target = $xml.CreateElement("Target")
        $target.SetAttribute("Name", "CopyCustomContent")
        $target.SetAttribute("AfterTargets", "AfterBuild")
        $xml.Project.AppendChild($target)
    }

    $existingItemGroup = $xml.Project.SelectNodes("//Target[@Name='CopyCustomContent']/ItemGroup/_CustomFiles[@Include='$($includePath)']")
    if ($existingItemGroup.Count -eq 0) {
    # The specified content doesn't exist, so add it
    $itemGroup = $xml.CreateElement("ItemGroup")
    $customFiles = $xml.CreateElement("_CustomFiles")
    $customFiles.SetAttribute("Include", "$($includePath)")
    $itemGroup.AppendChild($customFiles)
    $target.AppendChild($itemGroup)

    $copyElement = $xml.CreateElement("Copy")
    $copyElement.SetAttribute("SourceFiles", "@(_CustomFiles)")
    $copyElement.SetAttribute("DestinationFolder", $($destinationFolder))
    $target.AppendChild($copyElement)

    # Save the changes to the csproj file
    $saveFile=$true
    Write-Host "Git Hooks added to $($filePath)"
    }    
    Save-File -filePath $filePath -saveFile $saveFile
}

<#
.SYNOPSIS
Ensure .nuspec has all the properties needed
#>
function Confirm-Nuspec-Properties {
    param (
        [string]$filePath
    )
    $xml = [xml](Get-Content $filePath)
    $missingProperties = @()
    $properties = @{
        'id' = $xml.package.metadata.id
        'title' = $xml.package.metadata.title
        'description' = $xml.package.metadata.description
        'authors' = $xml.package.metadata.authors
    }

    $parent = $xml.package.metadata
    $saveFile = $false

    foreach ($property in $properties.GetEnumerator()) {
        if ($null -eq $property.Value) {
            $missingProperties += $property.Key
        }
    }

    if ($missingProperties.Count -gt 0) {
        $saveFile = $true
        Write-Host "The following properties are missing : $($missingProperties -join ', ')"
        Write-Host "Please enter the missing property values:"

        # Prompt the user to enter missing property values
        foreach ($missingProperty in $missingProperties) {
            $value = Read-Host "Enter $($missingProperty)"
            $properties[$missingProperty] = $value
        }

        # Add the missing properties 
        foreach ($missingProperty in $missingProperties) {
            $propertyElement = $xml.CreateElement($missingProperty)
            $propertyElement.InnerText = $properties[$missingProperty]
            $parent.AppendChild($propertyElement)
        }
    } 

    Save-File -filePath $filePath -saveFile $saveFile

    if($saveFile -eq $false){
        Write-Host "All required properties exist in .nuspec"
        Write-Verbose ("[Confirm-Nuspec-Properties] Saving file to: $($filePath)")
    }

    return [PSCustomObject]@{
        Id = '"' + $xml.package.metadata.id + '"'
        Title = '"' + $xml.package.metadata.title + '"'
        Description = '"' + $xml.package.metadata.description + '"'
        Authors = '"' + $xml.package.metadata.authors + '"'
    }
}

function Save-File {
    param (
        [string]$filePath,
        $saveFile
    )
    if($saveFile -eq $true)
    {
        # Save the changes to the csproj file
        $xml.Save($filePath)
        Write-Host "Updated $($filePath)"
    } 
}

<#
.SYNOPSIS
Ensures the path will be absolute
#>
function Use-Absolute-Path {
    param (
        [string]$isRelativeFromPath,
        [string]$path,
        [switch]$isDirectory    
    )

if(([System.IO.Path]::IsPathRooted($path)) -and ($isDirectory.IsPresent))
{
    # Ensures that the last character on the extraction path is the directory separator char.
    if(-not $path.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString(), [StringComparison]::Ordinal)){
        $path += [System.IO.Path]::DirectorySeparatorChar;
    }
    return $path
}
else 
{
    if ([string]::IsNullOrWhiteSpace($isRelativeFromPath)) {
        return Resolve-Path $path
    } 
    return Resolve-Path -Path (Join-Path -Path $isRelativeFromPath -ChildPath $path)
}
}

function Test-NuSpec-Exists {
    param (
        [string]$nuspecFilePath,
        [string]$defaultPath
    )
    if ([string]::IsNullOrWhiteSpace($nuspecFilePath)) {
        $nuspecPath = Join-Path -Path $rootPath -ChildPath $defaultPath
        if (Test-Path $nuspecPath) {
            $nuspecFilePath = Resolve-Path $nuspecPath
            Write-Verbose ("[Test-NuSpec-Exists] .nuspec path: $nuspecFilePath")
            return $nuspecFilePath
        }
        else {
            Write-Host "no .nuspec found at path ${nuspecPath}"
            exit 1
        }
    }
    return Use-Absolute-Path -path $nuspecFilePath -isRelativeFromPath $cakeReleaseDirectory
}

<#
.SYNOPSIS
 Gets csproj path
#>
function Get-Csproj-Path{
    param (
        [string]$csprojPath
)

if ([string]::IsNullOrWhiteSpace($csprojPath)) {
    $csprojFiles = Get-ChildItem -Path $rootPath -Recurse -Filter *.csproj | Where-Object { $_.Name -notmatch "\.Tests\.csproj$" }
    # Check if only one csproj file exists
    if ($csprojFiles.Count -ne 1)
    {
        Write-Host "Found $($csprojFiles.Count) csproj files. Please specify which csproj file to use"   
        exit 1
    }
    else {
        $csprojPath = $csprojFiles[0].FullName
    }
}
Write-Verbose ("[Get-Csproj-Path] csprojPath: $csprojPath")
return $csprojPath
}

# Ensures parameter value has been assigned
function Confirm-String-Parameter {
    param (
        [string]$param,
        [string]$prompt
    )
    if ([string]::IsNullOrWhiteSpace($param)) {
        $param = read-host -Prompt $prompt
    } 
    return $param
}

<#
.SYNOPSIS
Formats path with double backslash
#>
function Format-With-Double-Backslash{
    param (
        [string]$string
    )
    for ($i = 0; $i -lt $string.Length; $i++) {
        # If the character is a backslash
        if ($string[$i] -eq '\') {
            # If the backslash is followed by another backslash
            if (($i + 1) -lt $string.Length -and $string[$i + 1] -eq '\') {
                # Add the two backslashes to the result and skip the next character
                $result += '\\'
                $i++
            } else {
                # Add a double backslash to the result
                $result += '\\'
            }
        } else {
            # Add the current character to the result
            $result += $string[$i]
        }
    }
    return $result
}
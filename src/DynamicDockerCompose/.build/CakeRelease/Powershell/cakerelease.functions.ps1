function Confirm-Package-Json-Properties {
    param (
        [string]$filePath,
        [string]$packageId,
        [switch]$verbose
    )
    if($verbose.IsPresent){ 
        Write-Host "Checking package.json path: " $filePath
        }
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

function Copy-Git-Hooks {
    param (
        [string]$filePath,
        [string]$includePath,
        [string]$destinationFolder,
        [switch]$verbose
    )
    if($verbose.IsPresent){
        Write-Host "Copying Git Hooks..."
    }
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
    Save-File -filePath $filePath -saveFile $saveFile -verbose:$verbose
}

function Confirm-Nuspec-Properties {
    param (
        [string]$filePath,
        [switch]$verbose
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

    Save-File -filePath $filePath -saveFile $saveFile -verbose:$verbose

    if($saveFile -eq $false){
        Write-Host "All required properties exist in .nuspec" -NoNewline
        if($verbose.IsPresent){
            Write-Host ": $($filePath)"
        }
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
        $saveFile,
        [switch]$verbose
    )
    if($saveFile -eq $true)
    {
        # Save the changes to the csproj file
        $xml.Save($filePath)
        Write-Host "Updated $($filePath)"
    } 
}

function Test-NuSpec-Exists {
    param (
        [string]$nuspecFilePath,
        [string]$defaultPath,
        [switch]$verbose
    )
    Write-Host ".nuspec path: " $nuspecFilePath
    if ([string]::IsNullOrWhiteSpace($nuspecFilePath)) {
        $nuspecPath = Join-Path -Path $rootPath -ChildPath ".\.build\CakeRelease\Package\${nuspec}"
        if (Test-Path $nuspecPath) {
            $nuspecFilePath = Resolve-Path $nuspecPath
            if($verbose.IsPresent){ 
            Write-Host ".nuspec path: " $nuspecFilePath
            }
        }
        else {
            Write-Host "no .nuspec found at path ${nuspecPath}"
            exit 1
        }
    }
    return $nuspecFilePath
}

# Get csproj path
function Get-Csproj-Path{
    param (
        [string]$csprojPath,
        [switch]$verbose
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
if($verbose.IsPresent){ 
    Write-Host "csprojPath: " $csprojPath
}
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
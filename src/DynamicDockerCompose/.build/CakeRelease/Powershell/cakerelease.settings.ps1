$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

# Relative path from PSScriptRoot
$rootPathFolder = "../.."

$rootPath = Resolve-Path (Join-Path -Path $cakeReleaseDirectory -ChildPath $rootPathFolder)
$semanticConfigPath = Join-Path -Path $cakeReleaseDirectory -ChildPath ".\Semantic\Config\"
$mainConfigPath = Join-Path -Path $semanticConfigPath -ChildPath ".\main.js"
$releaseConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "../.releaserc.js"
$packageJsonPath = Join-Path -Path $cakeReleaseDirectory -ChildPath "../../package.json"

# Semantic Release config file
$githubConfig = $null
if($createGithubRelease.IsPresent)
{
	$githubConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "github.js"
	$githubConfig = Get-Content -Path $githubConfigPath -Raw
}

$nugetConfig = $null
if($publishToNuget.IsPresent -or (-not [string]::IsNullOrWhiteSpace($publishToSource))){
	$nugetConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "nuget.js"
	$nugetConfig = Get-Content -Path $nugetConfigPath -Raw
}

# .build folder path
$buildPath = ""
if(-not $autoBuild.IsPresent)
{
	$buildPath = "../"
}

# Cake build
$cakePath = Join-Path -Path $cakeReleaseDirectory -ChildPath ".\Cake"

# Get nuspecFile path
$nuspec = ".nuspec"
if($autoBuild.IsPresent){
    $nuspec = "release.nuspec"
}

$nuspecFilePath = Test-NuSpec-Exists -nuspecFilePath $nuspecFilePath -defaultPath ".\.build\CakeRelease\Package\${nuspec}" -verbose:$verbose

# Git Hooks
$gitHooksFolder=""
if(-not $autoBuild.IsPresent){
	$gitHooksFolder = ".\..\"
}
$csprojTargetGitHooksCommitMsgPath = "${gitHooksFolder}.build\CakeRelease\Git\Hooks\commit-msg"
$csprojTargetGitHooksCommitMsgDestinationFolder = "./../../../.git/hooks"
Import-Module InvokeBuild -Force
# Variables to be used during build process
if ($null -ne $hostinvocation) { $buildRoot = Split-Path $hostinvocation.MyCommand.path } else { $buildRoot = Split-Path $script:MyInvocation.MyCommand.Path }
$moduleName = 'PSLog'
$ModuleManifestName = 'PSLog.psd1'
$ManifestPath = "$($buildRoot)\$($moduleName)\$($ModuleManifestName)"
$Artifacts = "$($buildRoot)\Artifacts"
if (!(Test-Path -Path $Artifacts))
{
    New-Item -ItemType Directory -Path $Artifacts -Force
}

task InstallDependencies {
    # Install any modules that are required for the build process
    if (!(Get-Module -Name Pester -ListAvailable)) { Install-Module Pester -Force -Scope CurrentUser }
    Import-Module -Name Pester -Force
    if (!(Get-Module -Name PSScriptAnalyzer -ListAvailable)) { Install-Module PSScriptAnalyzer -Force -Scope CurrentUser }
    Import-Module -Name PSScriptAnalyzer -Force
    if (!(Get-Module -Name Configuration -ListAvailable)) { Install-Module Configuration -Force -Scope CurrentUser }
    Import-Module -Name Configuration -Force
}

task Analyze {
    # Get PSScriptAnalyzer Settings
    $rules = "$($BuildRoot)\ScriptAnalyzerSettings.psd1"
    # Identify files to be verified
    $scripts = Get-ChildItem -Path "$($BuildRoot)\$moduleName" -Include '*.ps1', '*.psm1', '*.psd1' -Recurse | Where-Object FullName -notmatch 'Classes'
    # create result array
    $results = @()
    # Loop through the scripts and verify them against the script analyzer settings
    foreach ($script in $scripts)
    {
        $result = Invoke-ScriptAnalyzer -Path $script.FullName -Settings $Rules
        if ($result)
        {
            $results += $result            
        }
    }
    # If there are any failed results, print them
    if ($results)
    {
        'One or more PSScriptAnalyzer errors/warnings were found.'
        'Please investigate or add the required SuppressMessage attribute.'
        $results | Format-Table -AutoSize
    }
    # assert that the build did not contain any results
    assert ($results.Count -eq 0) ( 'Failed during Analyze task' )
}

Task UpdateFunctionsToExport {
    # RegEx matches files like Verb-Noun.ps1 only, not psakefile.ps1 or *-*.Tests.ps1
    $functions = Get-ChildItem -Path "$($buildRoot)\$($moduleName)" -Recurse | Where-Object { $_.Name -match "^[^\.]+-[^\.]+\.ps1$" } -PipelineVariable file | ForEach-Object {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $null, [ref] $null)
        if ($ast.EndBlock.Statements.Name)
        {
            $ast.EndBlock.Statements.Name
        }
    }
    Write-Verbose "Using functions $functions"
    # Set functions to export
    Update-Metadata -Path $ManifestPath -PropertyName "FunctionsToExport" -Value @($functions)
}

task ImportModule {
    # If the module cannot be found
    if (-not(Test-Path -Path $ManifestPath))
    {
        "Module [$ModuleName] is not built; cannot find [$ManifestPath]."
        Write-Error -Message "Could not find module manifest [$ManifestPath]."
    }
    else
    {
        # Module found, and will re-load module incase its already loaded
        $loaded = Get-Module -Name $ModuleName -All
        if ($loaded)
        {
            "Unloading Module [$ModuleName] from a previous import..."
            $loaded | Remove-Module -Force
        }
        # Import module
        "Importing Module [$ModuleName] from [$ManifestPath]..."
        Import-Module -FullyQualifiedName $ManifestPath -Force
    }
}

task Test {
    # Invoke Pester testing with Test report in NUnitXML format
    $invokePesterParams = @{
        Strict       = $true
        PassThru     = $true
        Verbose      = $false
        EnableExit   = $false;
        OutputFile   = "$Artifacts/TestResults.xml" 
        OutputFormat = 'NUnitXml'
    }

    $testResults = Invoke-Pester @invokePesterParams;
    $numberFails = $testResults.FailedCount
    assert($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)
}

task UpdateAliasesToExport {
    # Get aliases
    $aliases = Get-Alias | Where-Object { $_.Source -eq $moduleName } | Select-Object -ExpandProperty Name
    Update-Metadata -Path $ManifestPath -PropertyName "AliasesToExport" -Value @($aliases)

}

task UpdateCmdletsToExport {
    # Get cmdlets
    $cmdlets = Get-Command -Module $moduleName -CommandType Cmdlet | Select-Object -ExpandProperty Name
    Update-Metadata -Path $ManifestPath -PropertyName "CmdletsToExport" -Value @($cmdlets)

}

task UpdateBuildVersion {
    # Get current manifest
    $Manifest = Import-PowerShellDataFile $ManifestPath
    [version]$version = $Manifest.ModuleVersion

    # Add one to the build of the version number
    [version]$NewVersion = "{0}.{1}.{2}" -f $Version.Major, $Version.Minor, ($Version.Build + 1) 

    # Update the manifest file
    Update-ModuleManifest -Path $ManifestPath -ModuleVersion $NewVersion
}

task Clean {
    # Clean folder
    if (Test-Path -Path $Artifacts)
    {
        Remove-Item "$Artifacts/*" -Recurse -Force
    }

    # Create folder if it doesnt exist
    New-Item -ItemType Directory -Path $Artifacts -Force
}

task Archive {
    # Read out the new module version
    $Manifest = Import-PowerShellDataFile $ManifestPath
    $version = $Manifest.ModuleVersion

    # Zip down the version ready for release
    Compress-Archive  -LiteralPath "$($buildRoot)\$($moduleName)" -DestinationPath "$Artifacts\$ModuleName.$version.zip"
}

# Default tasks
task . InstallDependencies, Analyze, UpdateFunctionsToExport , ImportModule, Test, UpdateAliasesToExport, UpdateCmdletsToExport, UpdateBuildVersion, Archive

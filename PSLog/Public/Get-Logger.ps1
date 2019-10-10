<#
.SYNOPSIS
    Return logger object to be used for logging to file
.DESCRIPTION
    Function accepts a configuration file to be used for controlling logging settiungs
    It also supports printing logs straight to host for easy debugging
.EXAMPLE
    PS C:\> $logger = Get-Logger
    PS C:\> $logger.Initialize($pathToConfigFile)
        Returns logger object based on configuration file.
.INPUTS
    None
.OUTPUTS
    Logger class
.NOTES
    General notes
#>
function Get-Logger
{
    return [Logger]::new()
}
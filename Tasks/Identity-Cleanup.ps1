param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory
 )


# #################################################
# File names for FTP transactions
# #################################################
 
$JobName = "Identity-Cleanup"

# #################################################
# Ensure that necesary folders exist
# #################################################

if ((test-path -Path $ScratchDirectory) -eq $false) {
    New-Item -Path $ScratchDirectory -ItemType Directory
}

if ((test-path -Path $LogDirectory) -eq $false) {
    New-Item -Path $LogDirectory -ItemType Directory
}

$OrigLocation = Get-Location
$ActualScratchPath = $(Resolve-Path $ScratchDirectory)
$ActualLogPath = $(Resolve-Path $LogDirectory)
$ActualConfigFilePath = $(Resolve-Path $ConfigFile)

# #################################################
# Functions
# #################################################

function Get-FullTimeStamp {
    $now=get-Date
    $yr=("{0:0000}" -f $now.Year).ToString()
    $mo=("{0:00}" -f $now.Month).ToString()
    $dy=("{0:00}" -f $now.Day).ToString()
    $hr=("{0:00}" -f $now.Hour).ToString()
    $mi=("{0:00}" -f $now.Minute).ToString()
    $timestamp=$yr + "-" + $mo + "-" + $dy + "-" + $hr + $mi
    return $timestamp
 }

# #################################################
# Load config file
# #################################################
if ((test-path -Path $ActualConfigFilePath) -eq $false) {
    Throw "Config file not found. Specify using -ConfigFile."
}

$configXML = [xml](Get-Content $ActualConfigFilePath)
$IdentityScriptsRootPath = $configXml.Settings.Identity.IdentityScriptsRootPath
$IdentityFacilityFile = $configXml.Settings.Identity.FacilityFile
$IdentityConfigFile = $configXml.Settings.Identity.ConfigFile

# Should probably check to make sure all these things have values...

# #################################################
# Run import scripts
# #################################################

foreach($InputFile in $CSVGetFiles) {    
    . $IdentityScriptsRootPath/Tasks/Cleanup.ps1 -ConfigFile $IdentityConfigFile -LogFilePath $ActualScratchPath
}

# #################################################
# Finished
# #################################################


write-host "Done"
set-location $OrigLocation
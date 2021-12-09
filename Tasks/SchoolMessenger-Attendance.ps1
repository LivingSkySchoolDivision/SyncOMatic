param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory,
    [Parameter(Mandatory=$true)][string]$OutFileName
 )


# #################################################
# File names for FTP transactions
# #################################################
 
$JobName = "SchoolMessenger-Attendance"



# #################################################
# Ensure that necesary folders exist
# #################################################

if ((test-path -Path $ScratchDirectory) -eq $false) {
    New-Item -Path $ScratchDirectory -ItemType Directory
}

if ((test-path -Path $LogDirectory) -eq $false) {
    New-Item -Path $LogDirectory -ItemType Directory
}

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
$WinSCPPath = $configXml.Settings.Utilities.WinSCPPath
$SevenZipPath = $configXml.Settings.Utilities.SevenZipPath
$LogFilePassword = $configXml.Settings.LogFilePassword

$VendorSFTPHost = $configXml.Settings.SchoolMessenger.SFTPHost
$VendorSFTPUser = $configXml.Settings.SchoolMessenger.SFTPUser
$VendorSFTPPassword = $configXml.Settings.SchoolMessenger.SFTPPassword
$VendorSFTPHostKey = $configXml.Settings.SchoolMessenger.SFTPHostKey

$EdsbyLinkRoot = $configXml.Settings.EdsbyLink.EdsbyLinkRootPath
$EdsbyLinkURL = $configXml.Settings.EdsbyLink.EdsbyLinkURL
$EdsbyLinkSchool = $configXml.Settings.EdsbyLink.EdsbyLinkSchool
$EdsbyLinkPassword = $configXml.Settings.EdsbyLink.EdsbyLinkPassword
$EdsbyLinkUserID =  $configXml.Settings.EdsbyLink.EdsbyLinkUserID

$UtilitiesScriptsRoot = $configXml.Settings.UtilitiesScriptsRoot

$PythonExe =  $configXml.Settings.PythonExecutable

# Should probably check to make sure all these things have values...


$OrigLocation = Get-Location
set-location $ActualScratchPath

# #################################################
# Clear scratch folder of any existing files
# #################################################

Get-ChildItem $ActualScratchPath |
Foreach-Object {
    if ($_.Name -ne ".placeholder") {
        Remove-Item $_.FullName
    }
} 

# #################################################
# Run EdsbyLink sync and get export files
# #################################################

$EdsbyLinkLogFile = (Join-Path $ActualScratchPath ("EdsbyLink.log"))
$EdsbyLinkParams = @(
    '-t', '0',
    $EdsbyLinkURL, 
    $EdsbyLinkSchool,
    '-e', '*',      
    '-o', $ActualScratchPath,
    '-u',$EdsbyLinkUserID,
    '-p', $EdsbyLinkPassword
    );

set-location $EdsbyLinkRoot
. $PythonExe edsbylink.py $EdsbyLinkParams > $EdsbyLinkLogFile
set-location $ActualScratchPath

# Delete files that we don't care about, but that Edsby gave us anyway
Get-ChildItem $ActualScratchPath |
Foreach-Object {
    if (($_.Name -notlike "SchoolMessenger*") -and ($_.Name -notlike "*.log")) {
        Remove-Item $_.FullName
    }
}

# #################################################
# Check to see if we got files, and exit this script if we didn't.
# Edsbylink sometimes just doesn't work.
# #################################################

$SchoolMessengerFilesFound = 0
Get-ChildItem $ActualScratchPath |
Foreach-Object {
    if ($_.Name -like "SchoolMessenger*") {
        $SchoolMessengerFilesFound++
    }
}

# We should get one file per school, so 31 files total. Sometimes we get 1 empty file.
if ($SchoolMessengerFilesFound -lt 2) {
    Write-Output "No usable files received from Edsby - aborting"
    Write-Output "No usable files received from Edsby - aborting" > "ERROR.log"
    set-location $OrigLocation
    exit
}

# #################################################
# Combine SchoolMessenger CSV files into a single file
# #################################################

$CombineLogFile = (Join-Path $ActualScratchPath ("Combiner.log"))
$ActualOutputPath = join-path $ActualScratchPath $OutFileName
$CombineCommandParams = @(
    '-InputDirectory', $ActualScratchPath 
    '-OutputFileName', $ActualOutputPath,
    '-HeaderLines', '2',
    '-FileFilter', 'SchoolMessenger*.csv'
);

. powershell.exe -Command $UtilitiesScriptsRoot/CombineCSVFiles.ps1 $CombineCommandParams > $CombineLogFile


# #################################################
# Send files to vendor
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $VendorSFTPUser@$VendorSFTPHost -password=$VendorSFTPPassword -hostkey=$VendorSFTPHostKey"
$SFTPCommands += "PUT $($ActualOutputPath)"
$SFTPCommands += "BYE"

$WinSCPLogFile = Join-Path $ActualScratchPath "winscp-vendor.log"
. $WinSCPPath/winscp.com  /command $SFTPCommands /log="$WinSCPLogFile" /loglevel=0


# #################################################
# Clean up scratch directory
# #################################################

$todayLogFileName = Join-Path $ActualLogPath "$(Get-FullTimeStamp)-$($JobName).7z"
. $SevenZipPath/7za.exe a -t7z $todayLogFileName -mx9 "-p$LogFilePassword" "$ActualScratchPath/*.*" -xr!".placeholder"

# Clear the rest of the scratch folder
Get-ChildItem $ActualScratchPath |
Foreach-Object {
    if ($_.Name -ne ".placeholder") {
        Remove-Item $_.FullName
    }
} 

# #################################################
# Finished
# #################################################

write-host "Done"
set-location $OrigLocation

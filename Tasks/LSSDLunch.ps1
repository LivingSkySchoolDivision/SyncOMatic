param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory
 )


# #################################################
# File names for FTP transactions
# #################################################
 
$JobName = "LSSDLunch"
$MSSExportFilename = "LSSD-Lunch.txt"

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
$SFTPHost = $configXml.Settings.MySchoolSask.SFTPHost
$SFTPUser = $configXml.Settings.MySchoolSask.SFTPUser
$SFTPPrivateKeyPath = $configXml.Settings.MySchoolSask.SFTPPrivateKeyPath
$SFTPHostKey = $configXml.Settings.MySchoolSask.SFTPHostKey
$WinSCPPath = $configXml.Settings.Utilities.WinSCPPath
$SevenZipPath = $configXml.Settings.Utilities.SevenZipPath
$LogFilePassword = $configXml.Settings.LogFilePassword
$LSSDLunchRootPath = $configXml.Settings.LSSDLunch.LSSDLunchRootPath
$LSSDLunchEXEName = $configXml.Settings.LSSDLunch.LSSDLunchEXEName
$LSSDLunchConfigFile = $configXml.Settings.LSSDLunch.LSSDLunchConfigFile
$LSSDLunchSchoolFilter = $configXml.Settings.LSSDLunch.LSSDLunchFilterSchools

# Should probably check to make sure all these things have values...

# #################################################
# Retrieve file from MSS SFTP
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $SFTPUser@$SFTPHost -privatekey=$SFTPPrivateKeyPath -hostkey=$SFTPHostKey"
$SFTPCommands += "GET $MSSExportFilename"
$SFTPCommands += "RM $MSSExportFilename"
$SFTPCommands += "BYE"

$OrigLocation = Get-Location
set-location $ActualScratchPath

# #################################################
# Retrieve file from MSS SFTP
# #################################################

$WinSCPLogFile = Join-Path $ActualScratchPath "winscp.log"
. $WinSCPPath/winscp.com  /command $SFTPCommands /log="$WinSCPLogFile" /loglevel=0

# #################################################
# Run import scripts
# #################################################

. $LSSDLunchRootPath/$LSSDLunchEXEName -c $LSSDLunchConfigFile -i "$ActualScratchPath/$MSSExportFilename" -d true -f $LSSDLunchSchoolFilter >> $ActualScratchPath/$MSSExportFilename.log

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
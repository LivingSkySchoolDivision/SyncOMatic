param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory
 )


# #################################################
# File names for FTP transactions
# #################################################
 
$JobName = "Clever-Sync"
$CSVGetFiles = @(
    @{ 
        MSSName = "Clever-Enrollments.csv"
        VendorName = "enrollments.csv"
    },
    @{ 
        MSSName = "Clever-Schools.csv"
        VendorName = "schools.csv"
    },
    @{ 
        MSSName = "Clever-Sections.csv"
        VendorName = "sections.csv"
    },
    @{ 
        MSSName = "Clever-Students.csv"
        VendorName = "students.csv"
    },
    @{ 
        MSSName = "Clever-Teachers.csv"
        VendorName = "teachers.csv"
    }
)

# #################################################
# Ensure that necesary folders exist
# #################################################

$ActualScratchPath = $(Resolve-Path $ScratchDirectory)
$ActualLogPath = $(Resolve-Path $LogDirectory)
$ActualConfigFilePath = $(Resolve-Path $ConfigFile)

if ((test-path -Path $ActualScratchPath) -eq $false) {
    New-Item -Path $ActualScratchPath -ItemType Directory
}

if ((test-path -Path $ActualLogPath) -eq $false) {
    New-Item -Path $ActualLogPath -ItemType Directory
}

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
$MSSSFTPHost = $configXml.Settings.MySchoolSask.SFTPHost
$MSSSFTPUser = $configXml.Settings.MySchoolSask.SFTPUser
$MSSSFTPPrivateKeyPath = $configXml.Settings.MySchoolSask.SFTPPrivateKeyPath
$MSSSFTPHostKey = $configXml.Settings.MySchoolSask.SFTPHostKey
$WinSCPPath = $configXml.Settings.Utilities.WinSCPPath
$SevenZipPath = $configXml.Settings.Utilities.SevenZipPath
$LogFilePassword = $configXml.Settings.LogFilePassword
$VendorSFTPHost = $configXml.Settings.Clever.SFTPHost
$VendorSFTPUser = $configXml.Settings.Clever.SFTPUser
$VendorPrivateKeyPath = $configXml.Settings.Clever.SFTPPrivateKeyPath
$VendorSFTPHostKey = $configXml.Settings.Clever.SFTPHostKey


$OrigLocation = Get-Location
set-location $ActualScratchPath

# #################################################
# Retrieve file from MSS SFTP
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $MSSSFTPUser@$MSSSFTPHost -privatekey=$MSSSFTPPrivateKeyPath -hostkey=$MSSSFTPHostKey"
foreach($file in $CSVGetFiles) {
    $SFTPCommands += "GET $($file.MSSName)"
}
$SFTPCommands += "BYE"


$WinSCPLogFile = Join-Path $ActualScratchPath "winscp-mss.log"
. $WinSCPPath/winscp.com  /command $SFTPCommands /log="$WinSCPLogFile" /loglevel=0


# #################################################
# Rename files to be what the vendor expects
# #################################################

foreach($file in $CSVGetFiles) {
    Rename-Item -Path $($file.MSSName) -NewName $($file.VendorName)
}



# #################################################
# Send files to vendor
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $VendorSFTPUser@$VendorSFTPHost -privatekey=$VendorPrivateKeyPath  -hostkey=$VendorSFTPHostKey"
foreach($file in $CSVGetFiles) {
    $SFTPCommands += "PUT $($file.VendorName)"
}
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
param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory
 )


# #################################################
# File names for FTP transactions
# #################################################
 
$JobName = "Xello-Sync"
$CSVGetFiles = @(
    @{ 
        MSSName = "Xello-Student.txt"
        VendorName = "Student.txt"
    },
    @{ 
        MSSName = "Xello-CourseCodes.txt"
        VendorName = "CourseCodes.txt"
    },
    @{ 
        MSSName = "Xello-StudentCourses-History.txt"
        VendorName = ""
    },
    @{ 
        MSSName = "Xello-StudentCourses-InProgress.txt"
        VendorName = "StudentCourses.txt"
    }
)

# We need to append files together for student enrolments
$AppendTo = "Xello-StudentCourses-InProgress.txt"
$AppendFrom = "Xello-StudentCourses-History.txt"

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
$MSSSFTPHost = $configXml.Settings.MySchoolSask.SFTPHost
$MSSSFTPUser = $configXml.Settings.MySchoolSask.SFTPUser
$MSSSFTPPrivateKeyPath = $configXml.Settings.MySchoolSask.SFTPPrivateKeyPath
$MSSSFTPHostKey = $configXml.Settings.MySchoolSask.SFTPHostKey
$WinSCPPath = $configXml.Settings.Utilities.WinSCPPath
$SevenZipPath = $configXml.Settings.Utilities.SevenZipPath
$LogFilePassword = $configXml.Settings.LogFilePassword
$VendorSFTPHost = $configXml.Settings.Xello.SFTPHost
$VendorSFTPUser = $configXml.Settings.Xello.SFTPUser
$VendorSFTPPassword = $configXml.Settings.Xello.SFTPPassword
$VendorSFTPHostKey = $configXml.Settings.Xello.SFTPHostKey

# Should probably check to make sure all these things have values...

$OrigLocation = Get-Location
set-location $ActualScratchPath

# #################################################
# Retrieve file from MSS SFTP
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $MSSSFTPUser@$MSSSFTPHost -privatekey=$MSSSFTPPrivateKeyPath -hostkey=$MSSSFTPHostKey"
foreach($file in $CSVGetFiles) {
    $SFTPCommands += "GET $($file.MSSName)"
    $SFTPCommands += "RM $($file.MSSName)"
}
$SFTPCommands += "BYE"

$WinSCPLogFile = Join-Path $ActualScratchPath "winscp-mss.log"
. $WinSCPPath/winscp.com  /command $SFTPCommands /log="$WinSCPLogFile" /loglevel=0

# #################################################
# Combine two StudentCourse files
# #################################################

Add-Content -Path $AppendTo -Value (Get-Content -Path $AppendFrom)
Remove-Item $AppendFrom

# #################################################
# The above section will screw up line endings for 
# half the file, so lets fix that
# #################################################

(Get-Content -Raw -Path $AppendTo) -replace '\r\n','`n' | Set-Content -Path $AppendTo

# #################################################
# Rename files to be what the vendor expects
# #################################################

foreach($file in $CSVGetFiles) {
    if ($file.VendorName.Length -gt 0) {
        Rename-Item -Path $($file.MSSName) -NewName $($file.VendorName)
    }
}

# #################################################
# Send files to vendor
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $VendorSFTPUser@$VendorSFTPHost -password=$VendorSFTPPassword -hostkey=$VendorSFTPHostKey"
$SFTPCommands += "option batch continue"
foreach($file in $CSVGetFiles) {
    if ($file.VendorName.Length -gt 0) {
        $SFTPCommands += "RM $($file.VendorName)"
        $SFTPCommands += "PUT $($file.VendorName)"
    }
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
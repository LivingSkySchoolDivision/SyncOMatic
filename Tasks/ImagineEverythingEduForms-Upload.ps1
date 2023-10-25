param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$ScratchDirectory,
    [Parameter(Mandatory=$true)][string]$LogDirectory
 )

# This script requires Amazon S3 powershell. How to install:
#  See: https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html#ps-installing-awstools
#  Install-Module -Name AWS.Tools.Installer -Force -AllowClobber
#  Install-AWSToolsModule AWS.Tools.S3 -CleanUp -Force -SkipPublisherCheck 


# #################################################
# File names for FTP transactions
# #################################################
 
$JobName = "IE-EDUFORMS"
$CSVGetFiles = @(
    @{ 
        MSSName = "ie-eduforms-staff.csv"
        VendorName = "Staff.csv"
    },
    @{ 
        MSSName = "ie-eduforms-speced.csv"
        VendorName = "SpecEd.csv"
    },
    @{ 
        MSSName = "ie-eduforms-schools.csv"
        VendorName = "Schools.csv"
    },
    @{ 
        MSSName = "ie-eduforms-contacts.csv"
        VendorName = "Contacts.csv"
    },
    @{ 
        MSSName = "ie-eduforms-sections.csv"
        VendorName = "Sections.csv"
    },
    @{ 
        MSSName = "ie-eduforms-students.csv"
        VendorName = "Students.csv"
    },
    @{ 
        MSSName = "ie-eduforms-teachers.csv"
        VendorName = "Teachers.csv"
    },
    @{ 
        MSSName = "ie-eduforms-enrolments.csv"
        VendorName = "Enrolments.csv"
    },
    @{ 
        MSSName = "ie-eduforms-PASI.csv"
        VendorName = "PASI_DATA.csv"
    },
    @{ 
        MSSName = "ie-eduforms-stuguardiancustody.csv"
        VendorName = "StuGuardianCustody.csv"
    }
)

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
$SevenZipPath = $configXml.Settings.Utilities.SevenZipPath
$LogFilePassword = $configXml.Settings.LogFilePassword
$WinSCPPath = $configXml.Settings.Utilities.WinSCPPath
$IES3BucketAccessKey = $configXml.Settings.ImagineEverythingEduForms.S3BucketAccessKey
$IES3BucketSecretKey = $configXml.Settings.ImagineEverythingEduForms.S3BucketSecret
$IES3BucketName = $configXml.Settings.ImagineEverythingEduForms.S3BucketName
$IES3Region = $configXml.Settings.ImagineEverythingEduForms.S3Region

$OrigLocation = Get-Location
set-location $ActualScratchPath

# #################################################
# Retrieve file from MSS SFTP
# #################################################

$SFTPCommands = @()
$SFTPCommands += "OPEN $MSSSFTPUser@$MSSSFTPHost -privatekey=$MSSSFTPPrivateKeyPath -hostkey=$MSSSFTPHostKey"
foreach($file in $CSVGetFiles) {
    $SFTPCommands += "GET $($file.MSSName)"
    #$SFTPCommands += "RM $($file.MSSName)"
}
$SFTPCommands += "BYE"

$WinSCPLogFile = Join-Path $ActualScratchPath "winscp-mss.log"
. $WinSCPPath/winscp.com  /command $SFTPCommands /log="$WinSCPLogFile" /loglevel=0


# #################################################
# Process the file to fix data issues, and also
# rename files to be what the vendor expects
# #################################################

foreach($file in $CSVGetFiles) {
    Rename-Item -Path $($file.MSSName) -NewName $($file.VendorName)
}

# #################################################
# Send files to vendor
# #################################################

foreach($file in $CSVGetFiles) {
    Write-S3Object -AccessKey $IES3BucketAccessKey -SecretKey $IES3BucketSecretKey -Region $IES3Region -BucketName $IES3BucketName -Key $file.VendorName -File $file.VendorName
}

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
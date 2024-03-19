param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$SQLQueryBase64,
    [Parameter(Mandatory=$true)][string]$OutputFile,
    [Parameter(Mandatory=$true)][string]$LogFile
)

Function LogThis
{
   Param ([string]$logmessage)
   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
   $Line = "$Stamp $logmessage"
   Add-content $Logfile -value $Line
}

LogThis "Starting Get-CSVFromSQL.ps1"

LogThis "SQL Query: $SQLQueryBase64"

$SQLQuery = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($SQLQueryBase64))

# #################################################
# Ensure that necessary folders exist
# #################################################

$ActualConfigFilePath = $(Resolve-Path $ConfigFile)
LogThis "Loading configuration file from $ActualConfigFilePath"

# #################################################
# Load config file
# #################################################
if ((Test-Path -Path $ActualConfigFilePath) -eq $false) {
    Throw "Config file not found. Specify using -ConfigFile."
}

$configXML = [xml](Get-Content $ActualConfigFilePath)
$SQLConnectionString = $configXml.Settings.MySchoolSask.ReportingDatabaseConnectionString

if ((Test-Path -Path $OutputFile) -eq $true) {
    Remove-Item $OutputFile
}

LogThis "Config file loaded.";

# #################################################
# Run SQL query
# #################################################

$connection = New-Object System.Data.SqlClient.SqlConnection($SQLConnectionString)
$command = New-Object System.Data.SqlClient.SqlCommand($SQLQuery, $connection)
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
$dataset = New-Object System.Data.DataSet

$retryCount = 0
$maxRetries = 5
$retryDelay = 60
$anysuccess = $false
$lastError = ""

LogThis "Max retries is $maxRetries. Retry delay is $retryDelay seconds."
LogThis "Running query..."

while ($retryCount -lt $maxRetries) {
    try {
        $adapter.Fill($dataset) | Out-Null
        $anysuccess = $true
        break
    } catch {
        $retryCount++
        if ($retryCount -eq $maxRetries) {
            LogThis "Failed to execute SQL query after $maxRetries attempts."
        }
        LogThis "Exception occurred."
        LogThis $_
        $lastError = $_
        LogThis "Retrying in $retryDelay seconds..."
        Start-Sleep -Seconds $retryDelay
    }
}

if ($anysuccess -eq $false) {
    LogThis "Failed to execute SQL query after $maxRetries attempts."
    throw "Failed to execute SQL query after $maxRetries attempts. $($lastError)"
    exit -1
}

LogThis "Finished running query."

# #################################################
# Process the query results
# #################################################

# You can access the query results using $dataset.Tables[0]

# #################################################
# Export results to CSV file
# #################################################

LogThis "Exporting results to $OutputFile"

if ($($dataset.Tables.Count) -gt 0) {
    $dataset.Tables[0] | Export-Csv -Path $OutputFile -NoTypeInformation
}

$OutFileHash = Get-FileHash $OutputFile -Algorithm SHA256
$OutFileSize = (Get-Item $OutputFile).Length
LogThis "SHA256 hash of $OutputFile is $($OutFileHash.Hash)"
LogThis "Size of $OutputFile is $OutFileSize bytes"

LogThis "Done running Get-CSVFromSQL.ps1."




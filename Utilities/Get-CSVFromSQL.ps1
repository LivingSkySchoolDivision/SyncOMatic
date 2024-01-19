param (
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$SQLQueryBase64,
    [Parameter(Mandatory=$true)][string]$OutputFile
)

$SQLQuery = [Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($SQLQueryBase64))
#write-host $SQLQuery

# #################################################
# Ensure that necessary folders exist
# #################################################

$ActualConfigFilePath = $(Resolve-Path $ConfigFile)

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


# #################################################
# Run SQL query
# #################################################

$connection = New-Object System.Data.SqlClient.SqlConnection($SQLConnectionString)
$command = New-Object System.Data.SqlClient.SqlCommand($SQLQuery, $connection)
$adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
$dataset = New-Object System.Data.DataSet

$retryCount = 0
$maxRetries = 5
$retryDelay = 30

while ($retryCount -lt $maxRetries) {
    try {
        $adapter.Fill($dataset) | Out-Null
        break
    } catch {
        $retryCount++
        if ($retryCount -eq $maxRetries) {
            throw "Failed to execute SQL query after $maxRetries attempts."
        }
        Write-Host "Exception occurred. Retrying in $retryDelay seconds..."
        Start-Sleep -Seconds $retryDelay
    }
}

# #################################################
# Process the query results
# #################################################

# You can access the query results using $dataset.Tables[0]

# #################################################
# Export results to CSV file
# #################################################

if ($($dataset.Tables.Count) -gt 0) {
    $dataset.Tables[0] | Export-Csv -Path $OutputFile -NoTypeInformation
}




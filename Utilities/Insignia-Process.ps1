param(
    [Parameter(Mandatory=$true)][string]$InputFileName,
    [Parameter(Mandatory=$true)][string]$OutputFileName
)

# This script corrects missing homerooms by replacing empty homerooms with grade numbers

# Check if input files exist
if ((Test-Path $InputFileName) -ne $true)
{
    write-host "Input file not found!"
    exit
}

if ((Test-Path $OutputFileName) -eq $true)
{
    Remove-Item $OutputFileName
}

# Read in input file

write-host "Loading input file..."
$InputFile = import-csv $InputFileName -Delimiter "`t"

$CSVLines = @()
foreach($Line in $InputFile)
{
    $ThisRow = [PSCustomObject]@{
        "Building ID" = $Line."Building ID"
        "Last Name" = $Line."Last Name"
        "First Name" = $Line."First Name"
        "Middle Name" = $Line."Middle Name"
        "Student ID" = $Line."Student ID"
        "Grade" = $Line."Grade"
        "Gender" = $Line."Gender"
        "Homeroom" = $Line."Homeroom"
        "Email" = $Line."Email"
    }
    $CSVLines += $ThisRow
}

# Process
write-host "Processing..."
foreach($Line in $CSVLines)
{
    if ($Line."Homeroom" -eq "") {
        $Line."Homeroom" = $Line."Grade"
    }
}

# Write output file
write-host "Writing output file..."
$file = [system.io.file]::OpenWrite($OutputFileName)
$writer = New-Object System.IO.StreamWriter($file)

# Use write instead of writeline so we can control the line endings better

# Writer header row
$writer.Write("Building ID`tLast Name`tFirst Name`tMiddle Name`tStudent ID`tGrade`tGender`tHomeroom`tEmail`n")

# Write values
foreach($Line in $CSVLines)
{
    $writer.Write("$($Line.'Building ID')`t$($Line.'Last Name')`t$($Line.'First Name')`t$($Line.'Middle Name')`t$($Line.'Student ID')`t$($Line.'Grade')`t$($Line.'Gender')`t$($Line.'Homeroom')`t$($Line.'Email')`n")
}

$writer.Close()
$file.Close()
Write-Output "Done!"
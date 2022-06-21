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
        "Last Name" = $Line."Last Name".Trim()
        "First Name" = $Line."First Name".Trim()
        "Middle Name" = $Line."Middle Name".Trim()
        "Student ID" = $Line."Student ID"
        "Grade" = $Line."Grade".Trim()
        "Gender" = $Line."Gender".Trim()
        "Homeroom" = $Line."Homeroom".Trim()
        "Email" = $Line."Email".Trim()
        "Address" = $Line."Address".Trim()
        "Address_2" = $Line."Address_2".Trim()
        "City" = $Line."City".Trim()
        "Province" = $Line."Province".Trim()
        "Country" = $Line."Country".Trim()
        "PostalCode" = $Line."PostalCode".Trim()
    }
    $CSVLines += $ThisRow
}

# Process
write-host "Processing..."
foreach($Line in $CSVLines)
{
    # If there is no homeroom, put the grade in instead
    if ($Line."Homeroom" -eq "") {
        $Line."Homeroom" = $Line."Grade"
    }

    # Condense address lines into a single field
    # In MSS, address lines are not what you expect
    # Line 2 is used for PO boxes, line 1 is used for street addresses
    # So we need to combine these into a single field
    # Looking at how our schools use these fields, some students will have values in both, so
    # if addr2 is present, we should always use that.

    if ($Line."Address_2" -ne "") {
        $Line."Address" = $Line."Address_2"
    }
}

# Write output file
write-host "Writing output file..."
$file = [system.io.file]::OpenWrite($OutputFileName)
$writer = New-Object System.IO.StreamWriter($file)

# Use write instead of writeline so we can control the line endings better

# Writer header row
$writer.Write("Building ID`tLast Name`tFirst Name`tMiddle Name`tStudent ID`tGrade`tGender`tHomeroom`tEmail`tAddress`tCity`tProvince`tCountry`tPostalCode`n")

# Write values
foreach($Line in $CSVLines)
{
    $writer.Write("$($Line.'Building ID')`t$($Line.'Last Name')`t$($Line.'First Name')`t$($Line.'Middle Name')`t$($Line.'Student ID')`t$($Line.'Grade')`t$($Line.'Gender')`t$($Line.'Homeroom')`t$($Line.'Email')`t$($Line.'Address')`t$($Line.'City')`t$($Line.'Province')`t$($Line.'Country')`t$($Line.'PostalCode')`n")
}

$writer.Close()
$file.Close()
Write-Output "Done!"
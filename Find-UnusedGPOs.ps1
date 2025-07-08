<#
.SYNOPSIS
    Scans all Group Policy Objects (GPOs) to find disabled or unlinked ones and exports the results.

.DESCRIPTION
    This script retrieves all GPOs, checks their status and links, and identifies potentially unused policies.
    It can export the findings to a CSV or HTML file for documentation and analysis.

.PARAMETER FilePath
    The full path to save the report file. If not provided, the output will only be displayed in the console.
    Example: C:\Reports\UnusedGPOs.csv

.PARAMETER Format
    The format for the exported file. Supported values are 'CSV' (default) and 'HTML'.

.EXAMPLE
    .\Find-UnusedGPOs.ps1
    (Scans and displays results in the console only)

.EXAMPLE
    .\Find-UnusedGPOs.ps1 -FilePath "C:\Audit\GPO_Report.csv"
    (Scans and saves the report as a CSV file)

.EXAMPLE
    .\Find-UnusedGPOs.ps1 -FilePath "C:\Audit\GPO_Report.html" -Format HTML
    (Scans and saves the report as a styled HTML file)

.NOTES
    Version: 1.1
    - Added export functionality to CSV and HTML.
    - Added parameters for specifying file path and format.
#>
param(
    [Parameter(Mandatory=$false, HelpMessage="Full path to the output file. Example: C:\Reports\UnusedGPOs.csv")]
    [string]$FilePath,

    [Parameter(Mandatory=$false, HelpMessage="Format of the output file. availables: CSV, HTML.")]
    [ValidateSet('CSV', 'HTML')]
    [string]$Format = 'CSV'
)

if (-not (Get-Module -Name GroupPolicy -ListAvailable)) {
    Write-Error "Module 'GroupPolicy' not found. Please install it using 'Install-Module GroupPolicy."
    return
}
Import-Module GroupPolicy

$problematicGPOs = @()

try {
    Write-Host "Scan all GPOs..." -ForegroundColor Cyan
    $allGPOs = Get-GPO -All -ErrorAction Stop
}
catch {
    Write-Error "cannot get all GPO. check permissions."
    return
}

$defaultGpoNames = "Default Domain Policy", "Default Domain Controllers Policy"

$totalGPOs = $allGPOs.Count
$counter = 0

Write-Host "Analyzing GPO..."
foreach ($gpo in $allGPOs) {
    $counter++
    Write-Progress -Activity "Analyzing GPO" -Status "Checking GPO $($gpo.DisplayName)" -PercentComplete (($counter / $totalGPOs) * 100)

    if ($gpo.GpoStatus -eq 'AllSettingsDisabled') {
        $problematicGPOs += [PSCustomObject]@{
            GPOName = $gpo.DisplayName
            GPOId   = $gpo.Id
            Status  = $gpo.GpoStatus
            Reason  = "GPO is disabled"
        }
        continue
    }

    if ($gpo.DisplayName -notin $defaultGpoNames) {
        try {
            $reportXml = Get-GPOReport -Guid $gpo.Id -ReportType Xml -ErrorAction Stop
            $xml = [xml]$reportXml
            
            if ($xml.GPO.LinksTo.ChildNodes.Count -eq 0) {
                $problematicGPOs += [PSCustomObject]@{
                    GPOName = $gpo.DisplayName
                    GPOId   = $gpo.Id
                    Status  = $gpo.GpoStatus
                    Reason  = "GPO is unlinked"
                }
            }
        }
        catch {
            Write-Warning "cannot generate report for GPO '$($gpo.DisplayName)' (ID: $($gpo.Id))."
        }
    }
}
Write-Progress -Activity "Analyzing GPO" -Completed

if ($problematicGPOs.Count -gt 0) {
    Write-Host "`nFound ($($problematicGPOs.Count)) potentialy unlinked or disabled GPO:" -ForegroundColor Green
    $problematicGPOs | Format-Table -AutoSize

    if (-not [string]::IsNullOrEmpty($FilePath)) {
        try {
            Write-Host "`nUploading report to file: $FilePath" -ForegroundColor Cyan
            
            $Directory = Split-Path -Path $FilePath -Parent
            if (-not (Test-Path -Path $Directory)) {
                New-Item -ItemType Directory -Path $Directory -Force | Out-Null
            }

            if ($Format -eq 'CSV') {
                $problematicGPOs | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
            }
            elseif ($Format -eq 'HTML') {
                $head = @"
<style>
body { font-family: 'Segoe UI', Arial, sans-serif; font-size: 14px; }
h1 { color: #333; }
table { border-collapse: collapse; width: 90%; margin: 20px 0; }
th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
th { background-color: #0078D4; color: white; }
tr:nth-child(even) { background-color: #f2f2f2; }
</style>
"@
                $bodyHeader = "<h1>Report of unused GPOs (from $(Get-Date))</h1>"
                
                $problematicGPOs | ConvertTo-Html -Head $head -Title "GPO Report" -Body $bodyHeader | Out-File -FilePath $FilePath -Encoding UTF8
            }
            Write-Host "Report saved to $FilePath" -ForegroundColor Green
        }
        catch {
            Write-Error "Cannot save report. Err: $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "`nNo unlinked or disabled GPOs found." -ForegroundColor Green
}

Write-Host "`nCheck completed." -ForegroundColor Cyan
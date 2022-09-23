$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    # "Logging in to Azure..."
    $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                             -ApplicationId $servicePrincipalConnection.ApplicationID   `
                             -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                             -ServicePrincipal
    # "Logged in."

}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#0: Sunday
#1: Monday
#2: Tuesday
#3: Wednesday
#4: Thursday
#5: Friday
#6: Saturday

Function Get-WeekNumberInMonth ()
{
  $currentday = (get-date -Hour 0 -Minute 0 -Second 0)
  $day = $currentday.day
  $WeekDay = [int]$currentday.dayofweek
  $Month = $currentday.Month
  $year = $currentday.Year
  $FirstDayOfMonth = Get-Date -Year $year -Month $Month -Day 1 -Hour 0 -Minute 0 -Second 0

  #First week day of the month (i.e. first monday of the month)
  [int]$FirstDayofMonthDay = $FirstDayOfMonth.DayOfWeek
  $Difference = $WeekDay - $FirstDayofMonthDay
  If ($Difference -lt 0)
  {
    $DaysToAdd = 7 - ($FirstDayofMonthDay - $WeekDay)
  } elseif ($difference -eq 0 )
  {
    $DaysToAdd = 0
  }else {
    $DaysToAdd = $Difference
  }
  $FirstWeekDayofMonth = $FirstDayOfMonth.AddDays($DaysToAdd)
  Remove-Variable DaysToAdd

  #find the weekNumber
    for ($week=1;$week -le 6;$week++){
        if ($FirstWeekDayofMonth.AddDays(($week-1)*7).day -eq $day `
            -and $FirstWeekDayofMonth.AddDays(($week-1)*7).month -eq $Month){
                return $week
            }
    }

    if ($week -eq 6) {
        Return -1
    }
}

#Get all ResourceId by using tag
$tagname = Get-AutomationVariable -Name 'tagname'
write-Output "Selecting subscription..."
Select-AzSubscription "aaa" #use this if you have more than 1 subs
write-Output "gathering all VM's with tag..."
$WeekInMonth = Get-WeekNumberInMonth #(Get-WmiObject Win32_LocalTime).weekinmonth ##for local use
$ListToSnapshot = Get-AzResource -TagName $tagname -TagValue $WeekInMonth

#Make snapshot
Foreach ($VM in $ListToSnapshot) 
    {
    $resourceGroupName = $VM.ResourceGroupName
    $location = $VM.Location
    $vmName = $VM.name
    $snapshotName = $VM.name+"$(get-date -Format 'yyyy-MM-dd')"
    $Temp = (Get-date).AddDays(7)
    $date = get-date $Temp -Format 'yyyy-MM-dd'
    $tag = @{"Remove after"="$date"}

    $vm = Get-AzVM `
        -ResourceGroupName $resourceGroupName `
        -Name $vmName

    $snapshot =  New-AzSnapshotConfig `
        -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id `
        -Location $location `
        -CreateOption copy `
        -Tag $tag
	write-Output "creatring snapshot..."
    New-AzSnapshot `
        -Snapshot $snapshot `
        -SnapshotName $snapshotName `
        -ResourceGroupName $resourceGroupName
}

# scan for remove shapshot
write-Output "remove old snapshots..."
$removaldate = get-date -Format 'yyyy-MM-dd'
$ListToRemove = Get-AzResource -TagName "Remove after" -TagValue $removaldate
    
foreach ($snap in $ListToRemove) {
    Remove-AzResource -ResourceId $snap.ResourceId -Force
}

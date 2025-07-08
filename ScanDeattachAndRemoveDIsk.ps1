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

$RGName = "XXX"
$VM = "XXX"
$DiskName = Get-AutomationVariable -Name 'DiskNameClone'

# Get the disk that you need to backup by creating snapshot
Select-AzSubscription -SubscriptionName "YYY"

# Deattach disk from VM
$VirtualMachine = Get-AzVM -ResourceGroupName $RGName -Name $VM
Remove-AzVMDataDisk -VM $VirtualMachine -Name $DiskName
Update-AzVM -ResourceGroupName $RGName -VM $VirtualMachine

# Remove Disk From Azure
Remove-AzDisk -ResourceGroupName $RGName -Name $DiskName -Force

# Remove Schedule
$automationAccountName = "your-automation-account-name"
$scheduleName = "test"
Set-AzContext -Subscription "SubscriptionID"
Remove-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $scheduleName -ResourceGroupName "ResGroupName" -Force

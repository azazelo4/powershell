### this script automaticaly:
### 1)take snapshot 
### 2)create disk from snapshot
### 3)move created disk to another subscription
### 4)attach disk to VM in another subscription

# Creating RunAs connection
$connectionName = "AzureRunAsConnection"
try {
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

# Variables where you tacke snapshot
$diskName = "Your Disk Name"
$resourceGroupName = "RG Name"
$snapshotName = "Name-$(get-date -Format 'yyyy-MM-dd-hh')"

#targeted VM where need to attach disk
$SubscriptionIDTar = 'SubsriptionID' 
$resourceGroupNameTar = 'RG Name'
$vmNameTar = 'VM name'

# Variables for creating Disk
$SnapshotResourceGroup = $resourceGroupName
$DiskNameOS = "$snapshotName-disk"

# 0) Get the disk that you need to backup by creating snapshot
Select-AzSubscription -SubscriptionName "select name of subs"
$yourDisk = Get-AzDisk -DiskName $DiskName -ResourceGroupName $resourceGroupName

# 1) Create snapshot by setting the SourceUri property with the value of the Id property of the disk
$snapshotConfig = New-AzSnapshotConfig -SourceUri $yourDisk.Id -Location $yourDisk.Location -CreateOption Copy
New-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Snapshot $snapshotConfig

# Chek that snapshot exist
Start-Sleep -s 60
try {
    $snapshotinfo = Get-AzSnapshot -ResourceGroupName $SnapshotResourceGroup -SnapshotName $snapshotName
}
catch {
    if (!$snapshotinfo)
    {
        $ErrorMessage = " $snapshotName not found."
    throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# 2) Create Disk
$snapshotinfo = Get-AzSnapshot -ResourceGroupName $SnapshotResourceGroup -SnapshotName $snapshotName
New-AzDisk -DiskName $DiskNameOS (New-AzDiskConfig -Location CentralUS -CreateOption Copy -SourceResourceId $snapshotinfo.Id) -ResourceGroupName $SnapshotResourceGroup

# 3) Move disk to another subscription (assign contributor role to RunAs account for both subsription)
$Move = Get-AzResource -ResourceGroupName $resourceGroupName -ResourceName $DiskNameOS
Move-AzResource -DestinationSubscriptionId $SubscriptionIDTar -DestinationResourceGroupName $resourceGroupNameTar -ResourceId $Move.ResourceId -Force

# 4) Attach Disk to targeted VM
Set-AzContext -Subscription $SubscriptionIDTar
$vm = Get-AzVM -Name $vmNameTar -ResourceGroupName $resourceGroupNameTar
$diskURI = Get-AzDisk -DiskName $DiskNameOS
$vm = Add-AzVMDataDisk -CreateOption Attach -Lun 0 -VM $vm -ManagedDiskId $diskURI.id
Update-AzVM -VM $vm -ResourceGroupName $resourceGroupNameTar

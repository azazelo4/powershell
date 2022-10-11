[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)] //max 3 char
    [string] $DOM = "Enter Domain",
    [Parameter(Mandatory = $true)] //max 3 char
    [string] $ROLE = "enter Role ",
    [Parameter(Mandatory = $true)]
    [string] $ENV = " enter environment.",
    [Parameter(Mandatory = $true)] //max 3 char
    [string] $NUM,
    [Parameter(Mandatory = $False)]
    [string] $vmSize = "Standard_B2s",
    [Parameter(Mandatory = $false)]
    [string] $userName = "admin",
	[Parameter (Mandatory = $false)]
    [string] $resourceGroupName = "enter RG name here",
	[Parameter (Mandatory = $false)]
    [string] $subscriptionName = "Microsoft Azure Enterprise",
	[Parameter(Mandatory = $false)]
    [string] $VirtualNetwork = "Enter VN name here",
	[Parameter(Mandatory = $false)]
    [string] $Subnet = "Enter subnet name",
	[Parameter(Mandatory = $true)]
    [string] $privateIP  = "xxx.xxx.xxx.$NUM",
	[Parameter(Mandatory = $false)]
    [string] $azRegion = "select region"
)

//max 3 char

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

$vmName        = "AZ$azRegion$DOM$ROLE-$ENV$NUM"
$vNicName      = "$vmName-vNic-01"
$Password      = (ConvertTo-SecureString "S0meG0odPas5w0rd" -Force -AsPlainText)
$Credential    = New-Object System.Management.Automation.PSCredential ($UserName, $Password)
$publisherName = "MicrosoftWindowsServer"
$offer         = "WindowsServer"
$sku           = "2019-Datacenter"
$version       = "Latest"


###################################### Main Script ################################################################################

Set-AzContext  -SubscriptionName $subscriptionName

write-host "Creating the new VM..." -ForegroundColor Yellow


$vNet = Get-AzVirtualNetwork -Name $VirtualNetwork -ResourceGroupName $resourceGroupName
$subnetId = $vNet.Subnets | Where-Object Name -eq $Subnet | Select-Object -ExpandProperty Id
if (!(get-AzNetworkInterface -Name $vNicName)) {
    $vNic = New-AzNetworkInterface -Name $vNicName -ResourceGroupName $resourceGroupName -Location $azRegion -SubnetId $subnetId -PrivateIpAddress $privateIP
}
else{
    $vNic = get-AzNetworkInterface -Name $vNicName
}

$vm = New-AzVMConfig -VMName $vmName -VMSize $vmSize
$vm = Set-AzVMOperatingSystem -VM $vm -Windows -ComputerName $vmName -Credential $Credential -ProvisionVMAgent
$vm = Add-AzVMNetworkInterface -VM $vm -Id $vNic.Id
$vm = Set-AzVMSourceImage -VM $vm -PublisherName $publisherName -Offer $offer -Skus $sku -Version $version

$res = New-AzVM -ResourceGroupName $resourceGroupName -Location $azRegion -VM $vm -LicenseType "Windows_Server" -Verbose


if ($res.StatusCode -eq "OK") {Write-Host "Done" -ForegroundColor Green} 
else {
    Write-host "Error" -ForegroundColor Red
    $res
} #

$azDataDiskName = "$vmName-data1"

$diskConfig = New-AzDiskConfig `
    -Location $azRegion `
    -CreateOption Empty `
    -DiskSizeGB 64 `
    -SkuName "Standard_LRS"

$dataDisk = New-AzDisk `
    -ResourceGroupName $resourceGroupName `
    -DiskName $azDataDiskName `
    -Disk $diskConfig

Get-AzDisk `
    -ResourceGroupName $resourceGroupName `
    -DiskName $azDataDiskName


$vm = Get-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName

$vm = Add-AzVMDataDisk `
    -VM $vm `
    -Name $azDataDiskName `
    -CreateOption Attach `
    -ManagedDiskId $dataDisk.Id `
    -Lun 1

$res = Update-AzVM `
    -ResourceGroupName $resourceGroupName `
    -VM $vm

if ($res.StatusCode -eq "OK") {Write-Host "Done" -ForegroundColor Green} 
else {
        Write-host "Error" -ForegroundColor Red
        $res
} #

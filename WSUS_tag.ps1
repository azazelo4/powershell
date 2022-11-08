# // need to install azure CLI module

#Var's
$Login = 'ServiceAccountName'
$Pass = 'S0me9oodP@s5'
$AzureVM = @()

# // Connect to Azure via Az CLI
az login -u $Login -p $Pass
$Subs = @("Microsoft Azure Enterprise 1";"Microsoft Azure Enterprise 2";"Microsoft Azure Enterprise 3";"Microsoft Azure Enterprise 4") # place your Subs here
Foreach ($Sub in $Subs) {
    az account set --subscription "$Sub"
    # // Make array with all VM's in Sub
    $VM = az vm list | ConvertFrom-Json
    foreach ($VMName in $VM) {
        $weekNum = $null
        write-host "working with" $vmname.name
        $VMhost = az vm get-instance-view -n $vmname.name -g $VMname.ResourceGroup |ConvertFrom-Json # // All about VM
        $VMhostname = $VMhost.instanceview.computername # //get hostname of VM
        write-host "$VMhostname"
        $GroupIDs = get-wsuscomputer -NameIncludes $VMhostname | select ComputerTargetGroupIds # // get groupID for compare and assign $weekNum
        if ($null -ne $GroupIDs) {  # // check that groupID not null
            Foreach ($GroupID in $GroupIDs.ComputerTargetGroupIds) { # // assign $weekNum
                Write-Host $GroupID
                if ($GroupID -eq 'GIUD for week 1') { # // Place your Group Giud's in WSUS
                      $weekNum = '1' 
                    } elseif ($GroupID -eq 'GIUD for week 2') {
                      $weekNum = '2'
                    } elseif ($GroupID -eq 'GIUD for week 3') {
                      $weekNum = '3'
                    } elseif ($GroupID -eq 'GIUD for week 4') {
                      $weekNum = '4'
                    } elseif ($GroupID -eq 'GIUD for week 0') {
                      $weekNum = '0'
                    } elseif (($GroupID -eq 'GIUD for "All PC group" ') -or ($GroupID -eq 'GIUD for "unassigned PC group"')) {   
                      Write-host "GROUP: ALL PC or Unassigned"
                    } else {
                      Write-Host $weekNum   
                }
            }  
        }
        $AzureVM += new-object PSObject -property (@{AZVMNAME = $vmname.name ; OSNAME = $VMhostname ; WEEK = $weekNum ; RG = $VMName.ResourceGroup})   #   // add to array VM hostname and week of update   
    }
    $AzureVM


    # // Assign TAG to Azure VM
    foreach ($AVM in $AzureVM) {
        if ($($AVM.WEEK) -ne $null) {
            write-host $AVM
            az vm update -g $($AVM.RG) -n $($AVM.AZVMNAME) --set tags.Updates=$($AVM.WEEK)
        }
    }
}

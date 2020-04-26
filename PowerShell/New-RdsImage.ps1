<#
    .SYNOPSIS
        Converts a running AzureRmure VM image to an AzureRmure Image to be used for a RDS session hosts.

    .PARAMETER ResourceGroupName
        The resource group name where the AzureRmure VM and disk are located.

    .PARAMETER VmName
        The name of the VM running in AzureRmure.

    .PARAMETER Location
        The AzureRmure region where the VM is located.

    .PARAMETER ImageName
        The name to be assigned to the image
    
    .PARAMETER SnapShot

    .EXAMPLE
        New-RdsImage.ps1 -ResourceGroupName "CRMDEVResourceGroup-WUS2" -VmName "RDSMASTER" -Location "West US 2" -ImageName "LENSRDSIMAGE" -SnapShot
#>

param 
(
    [string]
    $ResourceGroupName,

    [string]
    $VmName,

    [string]
    $Location,

    [string]
    $ImageName = ("LENSRDSIMAGE" + (Get-Date -Format FileDate))
)

$vm = Get-AzureRmVm -Name $VmName -ResourceGroupName $ResourceGroupName
$disk = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name

#Create Image Configuration
$ImageConfig = New-AzureRmImageConfig -Location $Location

$params = @{
    Image           = $ImageConfig
    OsState         = 'Generalized'
    OsType          = 'Windows'
    ManagedDiskId   = $disk.Id
}
$ImageConfig = Set-AzureRmImageOsDisk @params

#Create Image
Write-Output "Creating the Azure image named $ImageName"
$params = @{
    Image               = $ImageConfig
    ImageName           = $ImageName
    ResourceGroupName   = $ResourceGroupName
}
New-AzureRmImage @params

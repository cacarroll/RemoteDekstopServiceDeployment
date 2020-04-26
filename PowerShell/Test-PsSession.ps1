<#
    .SYNOPSIS
        Tests that a PSSession session can be established to the target.

    .PARAMETER Computers
        The string array of computers in the RDS farm.

    .PARAMETER Username
        The username for the account that will be used to install and configure the Remote Desktop Services farm.

    .PARAMETER Pwd
        The secure string password of the account used to install and configure the Remote Desktop Services farm.

    .PARAMETER ResourceGroupName
        The resource group name that contains the Azure compute.

    .PARAMETER TimeOutInMinutes
        The value in minutes before time out.
#>
param
(
    [parameter(Mandatory=$true)]
    $Computers,

    [parameter(Mandatory=$true)]
    [string]
    $UserName,

    [parameter(Mandatory=$true)]
    [securestring]
    $Pwd,

    [parameter(Mandatory=$true)]
    [string]
    $ResourceGroupName,

    [parameter(Mandatory=$true)]
    [int]
    $TimeOutInMinutes
)

$timeout = New-TimeSpan -Minutes $TimeOutInMinutes
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$Credential = New-Object System.Management.Automation.PSCredential ($userName, $pwd)

Write-Output "*** Verify a PsSession can be established ***"

foreach ($ComputerName in $Computers)
{
    Write-Output "Attempting to establish a PsSession to $ComputerName"

    $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction SilentlyContinue

    if ($session)
    {
        Write-Output "Successfully created a PsSession to $ComputerName"
    }
    else
    {
        do
        {
            Write-Output "Unable to esablish PsSession to $ComputerName.  Rebooting the Azure VM."
        
            Restart-AzureRmVM -Name ($ComputerName.split('.')[0]) -ResourceGroupName $ResourceGroupName
            
            Start-Sleep 180
        
            $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction SilentlyContinue

        }
        until  (($null -ne $Session) -or ($stopwatch.elapsed -gt $timeout))

        if ($session)
        {
            Write-Output "Successfully created a PsSession to $ComputerName after reboot."
        }
        else 
        {
            Throw "Failed to establish a PsSession to $ComputerName"
        }
    }
}

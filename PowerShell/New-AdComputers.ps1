<#
    .SYNOPSIS
        Prestages AD Computer Accounts in the domain.

    .PARAMETER Computers
        The string array of computers in the RDS farm.

    .PARAMETER Username
        The username of the account with permissions to create AD objects.

    .PARAMETER Pwd
        The secure string password of the UserName.

    .PARAMETER OuPath
        The AD OU to create the AD Computer Accounts.
#>
[CmdletBinding()]
param(

    [parameter(Mandatory=$true)]
    $Computers,

    [parameter(Mandatory=$true)]
    [string]
    $OuPath,

    [parameter(Mandatory=$true)]
    [string]
    $UserName,

    [parameter(Mandatory=$true)]
    [securestring]
    $Pwd
)

$Credential = New-Object System.Management.Automation.PSCredential ($userName, $Pwd)

if (-not (get-module ActiveDirectory))
{
    Install-WindowsFeature RSAT-AD-PowerShell
}

Write-output "Creating AD Computers objects"
foreach ($ComputerName in $Computers)
{
    if ($ComputerName -match ".")
    {
        $ComputerName  = $ComputerName.split('.')[0]
    }
    
    $params = @{
        Name = $ComputerName
        SamAccountName = $ComputerName
        path = $OuPath
        Credential = $Credential
    }
    
    Write-Output "Creating AD Object for $ComputerName"
    New-AdComputer @params
}

<#
    .SYNOPSIS
        Installs and configures a Remote Desktop Services Connection Brokers and Session Hosts servers.

    .PARAMETER Computers
        The string array of computers in the RDS farm.

    .PARAMETER Username
        The username for the account that will be used to install and configure the Remote Desktop Services farm.

    .PARAMETER Pwd
        The secure string password of the account used to install and configure the Remote Desktop Services farm.
#>
[CmdletBinding()]
param 
(
    [parameter(Mandatory=$true)]
    $Computers,

    [parameter(Mandatory=$true)]
    [string]
    $UserName,

    [parameter(Mandatory=$true)]
    [securestring]
    $Pwd
)

$Credential = New-Object System.Management.Automation.PSCredential ($userName, $pwd)

foreach ($computerName in ($computers | Where-Object {$_ -match "CB"}))
{
    try
    {
        Write-Output "Disabling UAC on $ComputerName"
        $Session = New-PsSession -ComputerName $computerName -Credential $Credential

        Invoke-Command -Session $Session -ScriptBlock {

            $params = @{
                Path = 'HKLM:Software\Microsoft\Windows\CurrentVersion\policies\system'
                Name = 'EnableLUA'
            }

            if ((Get-ItemProperty @params) -ne 0)
            {
                New-ItemProperty @params -PropertyType DWord -Value 0 -Force
            }
        }
    }
    catch{$_}
    finally 
    {
        Remove-PSSession -Session $Session
    }
}

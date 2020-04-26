<#
    .SYNOPSIS
        Enables Credssp on the client and target computers.

    .PARAMETER Computers
        The string array of computers to set Credssp as server.

    .PARAMETER Username
        The username to build the credential object.

    .PARAMETER Pwd
        The secure string password of the UserName.

#>
[CmdletBinding()]
param(

    [parameter(Mandatory=$true)]
    $Computers,
 
    [parameter(Mandatory=$true)]
    [string]
    $UserName,

    [parameter(Mandatory=$true)]
    [securestring]
    $Pwd
)

$Credential = New-Object System.Management.Automation.PSCredential ($userName, $Pwd)

foreach ($ComputerName in $Computers)
{
    Write-Output "Enable WSMANCredssp Delegation for $ComputerName"

    Enable-WSManCredSSP -Role Client -DelegateComputer $ComputerName -Force

    $session = New-PSSession -ComputerName $ComputerName -Credential $Credential

    Invoke-Command -Session $session -ScriptBlock {
        Enable-WSManCredSSP -Role Server -Force
    }

    $params = @{
        ComputerName    = $ComputerName
        Authentication  = 'Credssp'
        Credential      = $Credential
        ErrorAction     = 'SilentlyContinue'
    }

    if (Test-WSMan @params)
    {
        Write-Output "Succesfully enabled Credssp on $ComputerName"
    }
    else 
    {
        Throw "Failed to enable Credssp on $ComputerName"    
    }
}

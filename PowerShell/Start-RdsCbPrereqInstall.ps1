<#
    .SYNOPSIS
        Installs the ODBC Driver and VisualC++ Runtime on the connection brokers which is required in order to esablish a connection to the SQL server.

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
    $pwd
)

$Credential = New-Object System.Management.Automation.PSCredential ($userName, $pwd)

foreach ($computerName in ($computers | Where-Object {$_ -match 'CB0'}))
{
    Write-Output "Installing Prereq software on $ComputerName"
    
    if (-not(Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Product | where-object {$_.Name -eq "Microsoft ODBC Driver 17 for SQL Server"}))
    {
        try 
        {
            $Session = New-PsSession -ComputerName $ComputerName -Credential $Credential

            Invoke-Command -Session $session -ScriptBlock {
                $apps = @(
                    @{
                        Name = 'vc_redist.x64.exe'
                        Path = '\\phx.gbl\public\GCC-Storage\Private\TSBuildOut'
                        Arg = '/quiet'
                    },
                    @{
                        Name = 'msodbcsql.msi'
                        Path = '\\phx.gbl\public\GCC-Storage\Private\TSBuildOut'
                        Arg = 'IACCEPTMSODBCSQLLICENSETERMS=YES /quiet'
                    }
                )
    
                foreach ($app in $apps)
                {
                    $cmd = Join-Path $($app.Path) -ChildPath $($app.name)
                    if ($app.Name -match '.msi')
                    {
                        Start-Process msiexec.exe -Wait -ArgumentList "/I $cmd $($app.arg)"
                    }
                    if ($app.Name -match '.exe')
                    {
                        Start-Process $cmd -Wait -ArgumentList $($app.arg)
                    }
                }
            }
        }
        catch
        {
            Throw $_
        }
        finally 
        {
            Remove-PsSession $Session
        }
    }
    else
    {
        Write-Output "Prereq software previously installed on $ComputerName"
    }
}

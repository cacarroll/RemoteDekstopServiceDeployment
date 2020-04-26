<#
    .SYNOPSIS
        Installs and configures a Remote Desktop Services Connection Brokers and Session Hosts servers.

    .PARAMETER Computers
        The string array of computers in the RDS farm.

    .PARAMETER Username
        The username for the account that will be used to install and configure the Remote Desktop Services farm.

    .PARAMETER Pwd
        The secure string password of the account used to install and configure the Remote Desktop Services farm.

    .PARAMETER SqlPwd
        The password of the Azure Sql database.  This is used when establishing the connection string to the database.

    .PARAMETER Environment
        The deployment environment.  PROD,PPE,DEV
    
    .PARAMETER DomainName
        The domain name where the compute is deployed.
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
    $Pwd,

    [parameter(Mandatory=$true)]
    [string]
    $SqlPwd,

    [parameter(Mandatory=$true)]
    [string]
    $Environment,

    [parameter(Mandatory=$true)]
    [string]
    $DomainName
)
Write-Output "***RDS Installation Starting***"
$ConnectionBrokers = ($Computers | Where-Object {$_ -match 'CB'}) -split " "
# # GPO licensing fix
Write-Output "GPO sets licensing servers which prevents creation of the Session Collection.  Deleting registry keys."
$Credential = New-Object System.Management.Automation.PSCredential ($userName, $pwd)
foreach ($ComputerName in $Computers)
{
    $Session = New-PSSession -ComputerName $ComputerName -Credential $Credential
    try
    {
        Invoke-Command -Session $Session -ScriptBlock {
            Remove-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicenseServers" -Confirm:$false -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\Terminal Services" -Name "LicensingMode" -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    catch {$_}
    finally
    {
        Remove-PsSession $Session
    }
}

$params = @{
    ConnectionBroker   = $Computers[0]
    ErrorAction        = 'SilentlyContinue'
}

if (-not (Get-RdServer @params))
{
    Write-Output "Starting RDS role deployments"

    $params = @{
        ConnectionBroker    = $Computers[0]
        SessionHost         = $Computers
    }
    New-RdSessionDeployment @params
}
else
{
    Write-Output "RDS installation previously run.  Verifying all Session Hosts roles are installed."

    $shServers = Get-RDserver -Role "RDS-RD-SERVER"

    foreach ($sh in $Computers)
    {
        if ($Computers -notcontains $sh)
        {
            Write-Output "$sh does not have the RDS-RD Server role installed.  Installing now."

            Add-RDServer -Server $Sh -Role RDS-RD-SERVER -ConnectionBroker $Computers[0]
        }
    }
}

# Initial role deployments
Write-Output "Configuring High Availablity and Session Host Collection"
$Session = New-PSSession -ComputerName $Computers[0] -Credential $Credential -Authentication Credssp
Invoke-Command -Session $Session -ScriptBlock {
    #Set Variables
    if ($using:Environment -eq "ppe")
    {
        $ClientAccessName = 'gcc' + $using:Environment + 'ts.' + $using:DomainName
    }
    elseif ($using:Environment -eq "prd")
    {
        $ClientAccessName = 'gccphxts.' + $using:DomainName
    }
    $SqlAdminName = 'lens' + $using:Environment + 'sql'
    $SqlDatabase = 'lens' + $using:Environment + 'rdsql.database.windows.net'
    $DatabaseConnectionString = "Driver={ODBC Driver 17 for SQL Server};Server=tcp:$SqlDatabase,1433;Database=rdsconnectionbroker;Uid=$sqlAdminName;Pwd=$using:sqlPwd;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    $ConnectionBrokers = ($using:Computers | Where-Object {$_ -match 'CB'}) -split " "
    $SessionHosts = ($using:Computers | Where-Object {$_ -match 'SH'})
    $CollectionName = 'LENS' + $using:Environment + 'DESKTOPS'
    $Computers = $using:Computers

    Write-Output "Here are the SessionHosts: $SessionHosts"
    Write-Output "Here are the ConnectionBroker:  $ConnectionBrokers"

    # Configure HighAvailablity
    Write-Output "Configure Connection Brokers for high availability"
    if(-not(Get-RdConnectionBrokerHighAvailability $Computers[0]))
    {
        $params = @{
            ConnectionBroker            = $Computers[0]
            DatabaseConnectionString    = $DatabaseConnectionString
            ClientAccessName            = $ClientAccessName
        }
        Set-RDConnectionBrokerHighAvailability @params
    }
    else 
    {
        Write-Output "Connection Broker previously configured for high availablity"
    }

    # Add additional CB's to be high-avail
    # There was an architecture change due to limited IP address space in Prod.  All servers are CB/SH
    foreach ($cb in ($Computers | Where-Object {$_ -notmatch '01'}))
    {
        if(-not(Get-RdConnectionBrokerHighAvailability $cb -ErrorAction SilentlyContinue))
        {
            Write-Output "Adding $CB to High Availablity Connection Farm"
            $params = @{
                Server              = $cb
                Role                = 'RDS-CONNECTION-BROKER'
                ConnectionBroker    = $Computers[0]
            }
            Add-RdServer @params
        }
    }

    # Create Session Collection
    if (-not(Get-RdSessionCollection -ConnectionBroker $ConnectionBrokers[0] -CollectionName $CollectionName -ErrorAction SilentlyContinue))
    {
        Write-Output "Creating Session Collection for $CollectionName"
        $params = @{
            CollectionName      = $CollectionName
            ConnectionBroker    = $Computers[0]
            SessionHost         = $Computers
        }
        New-RdSessionCollection @params -ErrorAction SilentlyContinue #Silently continue due to GPO for printer redirection Todo find / del registry entry

        Write-Output "Configuring Session Collection $CollectionName"
        $params = @{
            CollectionName          = $CollectionName
            UserGroup               = @('phx\EAD-GCC-Ops','phx\gcc-crm-tsusers')
            AuthenticateUsingNLA    = $true
            SecurityLayer           = 1
            EncryptionLevel         = 1
            MaxRedirectedMonitors   = 3
            ConnectionBroker        = $Computers[0]
        }
        Set-RdSessionCollectionConfiguration @params
    }

    # Configure SSL Connection Broker

#     ## Create Self Signed ###
#     $CertPassword = ConvertTo-SecureString -String "Cups34Horses&&" -AsPlainText -Force
#     $CertPath = 'C:\Certificates\RDCB.pfx'
    
#     $params = @{
#         DnsName             = $ClientAccessName 
#         Password            = $CertPassword
#         ExportPath          = $CertPath
#         ConnectionBroker    = $ConnectionBrokers[0]
#         Role                = 'RDRedirector'
#     }
    
#     New-RDCertificate @params
#     ###
    
#     foreach ($cb in $ConnectionBrokers)
#     {
#         $params = @{
#             ImportPath          = $CertPath
#             Password            = $CertPassword
#             ConnectionBroker    = $cb
#             Role                = 'RDRedirector'
#         }
        
#         Set-RDCertificate @params
#     }
}

## Setup Automatic Redirection to SessionCollection
# foreach ($cb in $ConnectionBrokers)
# {
#     $Session = New-PSSession -ComputerName $cb -Credential $Credential

#     Invoke-Command -Session $Session {
#         $CollectionName = 'LENS' + $using:Environment + 'REMOTEDESKTOPS'

#         Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings" -Name "DefaultTsvUrl" -Value "tsv://MS Terminal Services Plugin.1.$CollectionName"
#     }
# }

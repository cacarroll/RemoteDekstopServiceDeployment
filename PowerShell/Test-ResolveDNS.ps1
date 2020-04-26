<#
    .SYNOPSIS
        Installs and configures a Remote Desktop Services Connection Brokers and Session Hosts servers.

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
    $ResourceGroupName,

    [parameter(Mandatory=$true)]
    [int]
    $TimeOutInMinutes
)

$timeout = New-TimeSpan -Minutes $TimeOutInMinutes
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($ComputerName in $Computers)
{
    Write-Output "Verifing DNS record for $ComputerName"
   
    $params = @{
        Name = $ComputerName
        Type = 'A'
        ErrorAction = 'SilentlyContinue'
    }
    
    $DnsResponse = Resolve-DnsName @params -NoHostsFile

    if (-not $DnsResponse)
    {
        do
        {
            Write-Output "DNS record for $ComputerName not found.  Trying again in 60 seconds."
            
            Start-Sleep 60
    
            $DnsResponse = Resolve-DnsName @params -NoHostsFile
        }
        until (($DnsResponse) -or ($stopwatch.elapsed -ge $timeout))
    }

    if ($DnsResponse)
    {
        Write-Output "DNS record for $ComputerName found.  Will now check if A record matches the IP assiged to the VM."
    }
    else
    {
        Throw "DNS Record not found for $ComputerName."
    }

    $NicName = ($ComputerName.split('.')[0]) + 'Nic'

    $Ip = (Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName).IpConfigurations.PrivateIpAddress
    
    Write-Output "The A record has an IP assigned of $($DnsResponse.IpAddress) and the Azure VM has an IP address of $Ip."

    if ($($DnsResponse.IPAddress) -ne $ip)
    {
        $count = 1
        do 
        {
            $Ip = (Get-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName).IpConfigurations.PrivateIpAddress
            
            $DnsResponse = Resolve-DnsName @params -NoHostsFile
    
            Write-Output "Attempt $Count The A record has an IP assigned of $($DnsResponse.IpAddress) and the Azure VM has an IP address of $Ip.  Will try again in 60 Seconds."
            
            Start-Sleep 60
    
            $count++
    
            if ($count -eq 5 -or $count -eq 10)
            {
                Write-Output "$ComputerName does not have a valid DNS record after $count attempts. Rebooting VM"
                
                Restart-AzureRmVM -Name ($ComputerName.split('.')[0]) -ResourceGroupName $ResourceGroupName
    
                Start-Sleep 180
            }
            
        }
        until (($($DnsResponse.IPAddress) -eq $ip) -or ($stopwatch.elapsed -ge $timeout))
    }
    
    if ( $($DnsResponse.IpAddress) -eq $ip)
    {
        Write-Output "A valid DNS record was found for $ComputerName"
    }
    else
    {
        Throw "Unable to find a valid DNS record for $ComputerName"
    }
}

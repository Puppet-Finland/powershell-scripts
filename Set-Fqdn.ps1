param(
    [string]$hostname,
	[string]$domain
)
<#
.SYNOPSIS
    Set computername and DNS suffices

.DESCRIPTION
    This script sets the computer name, primary DNS suffix and primary network
	adapter's connection specific suffix based on given parameters. This may be
	necessary to make Puppet's $::fqdn fact resolve correctly, e.g. on EC2.
	
    This script requires administrative privileges.

.PARAMETER hostname
    The hostname of the computer. For example 'server'.

.PARAMETER domain
	The domain name of the computer. For example 'example.org'.
#>
function SetComputerName {
	param(
	[string]$hostname
	)
	Write-Host "Setting computername to ${hostname}"
	$computersystem = Get-WmiObject Win32_ComputerSystem
	$computersystem.Rename($hostname) > $null
}

function SetPrimaryDNSSuffix {
	param(
	[string]$domain
	)
	Write-Host "Setting primary DNS suffix to ${domain}"
	Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" -Name Domain -Value domain
	Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\" -Name "NV Domain" -Value $domain
}

function SetPrimaryNetworkAdapterConnectionSuffix {
	param(
	[string]$domain
	)
	Write-Host "Setting primary network adapter connection-specific suffix to ${domain}"
	$ifIndex = (Get-Netadapter).ifIndex
	Set-DnsClient -Interfaceindex $ifIndex -ConnectionSpecificSuffix $domain
}

if(-not($hostname)) { throw "You must supply a value for -Hostname" }
if(-not($domain)) { throw "You must supply a value for -Domain" }

SetComputerName -Hostname $hostname
SetPrimaryDNSSuffix -Domain $domain
SetPrimaryNetworkAdapterConnectionSuffix -Domain $domain


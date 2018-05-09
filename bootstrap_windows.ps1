param(
    [string]$ServerName,
    [string]$certName,
    [string]$puppetServerAddress
)
<#
.SYNOPSIS
    Installs and confogures Puppet agent on this machine.

.DESCRIPTION
    Downloads, confoigures and installs the PuppetLabs Puppet MSI package.

    This script requires administrative privileges.

    You can run this script from an old-style cmd.exe prompt using the
    following:

      powershell.exe -ExecutionPolicy Unrestricted -NoLogo -NoProfile -Command "& '.\windows.ps1'"

.PARAMETER certName
    This is the desired fqdn of the to-be-configured machine. This defaults
    to a value gotten from a win32_computersystem wimobject.

.PARAMETER ServerName
    This is fqdn of your Puppet server. 

.PARAMETER puppetServerAddress
    This is ip address of your Puppet server. 
#>

#
# Setup hostname and ip address of puppet server to be sure
#
function SetupHostsFile {

    param(
        [IPADDRESS]$puppetServerAddress,
	[String]$puppetServerName
    )

    if ($debug) {
	write-host ("Now in function {0}." -f $MyInvocation.MyCommand)
    }


    If (-Not [BOOL]($puppetServerAddress -as [IPADDRESS])) {
	write-host ("{0} is not an IP address" -f $puppetServerAddress)
	break
    }


    $fqdnRe='(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)'

    If ($puppetServerName -notmatch $fqdnRe) {
	write-host ("{0} is not a fully qualified name" -f $puppetServerName)
	break
    }

    write-host "Setting up hosts file..."

    $hostsFile = "$env:windir\System32\drivers\etc\hosts"

    if (!(Test-Path "$hostsFile")) {
	New-Item -path $env:windir\System32\drivers\etc -name hosts -type "file"
	Write-Host "Created new hosts file"
    }

    # Remove any lines containing our puppetservername
    $tempfile = $env:temp + "" + (get-date -uformat %s)
    New-Item $tempfile -type file -Force | Out-Null
    Get-Content $HostsFile | Where-Object {$_ -notmatch "$puppetServerName"} | Set-Content $tempfile
    Move-Item -Path $tempfile -Destination $HostsFile -Force

    # Insert name, address of puppetserver separated by a tab 
    $fields=@($puppetServerAddress,$puppetServerName)
    $myString=[string]::join("`t", (0,1 | % {$fields[$_]}))
    $found = Get-Content $hostsFile | Where-Object { $_.Contains("$myString") }
    if ([string]::IsNullOrEmpty($found)) {
	[string]::join("`t", (0,1 | % {$fields[$_]})) | Out-File -encoding ASCII -append $hostsFile
    }

    # Create access rule
    $userName = "Users"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$userName", 'Read', 'Allow')

    # Apply access rule
    $acl = Get-ACL $hostsFile
    $acl.SetAccessRule($rule)
    Set-Acl -path $hostsFile -AclObject $acl
    
}

#
# Retrieve and Install puppet agent
#
function InstallPuppetAgent() {

    if ($debug) {
        Write-Host ("Now in function {0}." -f $MyInvocation.MyCommand)
    }

    write-host "Installing management agent..."

    $url="https://downloads.puppetlabs.com/windows/puppet5/puppet-agent-x64-latest.msi"
    $tempfolder=$env:temp
    $installer="$tempfolder\puppet-agent-x64-latest.msi"
    $msiexec_switches="/qn /i"
    $logfile="$tempfolder\puppet.log"

    if (!(Test-Path "$installer")) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $url -Outfile "$installer"
        }
        catch {
            $ErrorMessage = $_.Exception.Message
	        write-host "Failed to retrive puppet agent installer. The error message was: $ErrorMessage"
            break
        }
    }

    try {
	    Start-Process -FilePath "msiexec.exe" -ArgumentList "$msiexec_switches $installer /log $logfile" -Wait
    }
    catch {
	    $ErrorMessage = $_.Exception.Message
	    write-host "Puppet agent installation failed. The error message was: $ErrorMessage"
        break
    }
}

#
# Configure puppet agent
#
function ConfigurePuppetAgent {

    param(
        [string]$ServerName,    
	    [string]$puppetBin = 'C:\Program Files\Puppet Labs\Puppet\bin\puppet.bat',
        [String]$myFQDN = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain
    )

    if ($debug) {
        write-host ("Now in function {0}." -f $MyInvocation.MyCommand)   
    }

    write-host "Configuring management agent..."
    $myFQDN = $myFQDN.ToLower() 
   
    try {
	& $puppetBin config --section main set server $ServerName
	& $puppetBin config --section agent set server $ServerName
        & $puppetBin config --section agent set certname $myFQDN
    }
    catch {
	    $ErrorMessage = $_.Exception.Message
	    write-host "Puppet agent configuration failed. The error message was: $ErrorMessage" 
	    break
    }

}

#
# Run puppet once to create keys and get the certificate
#
function RunPuppet { 
    param(
	[string]$ServerName,
	[string]$puppetBin = 'C:\Program Files\Puppet Labs\Puppet\bin\puppet.bat',
	[int]$timeoutSeconds = 120
    )
    $code = {
	param($hash)
        & $hash['puppetBin'] agent --no-daemonize --waitforcert 60 --onetime --server $hash['ServerName']
    }

    write-host "Running management agent initially to get our certificate, or timeouting in $timeoutSeconds seconds..."   
    $j = Start-Job -ScriptBlock $code -Argumentlist @{"ServerName"=$ServerName;"puppetBin"=$puppetBin}
    if (Wait-Job $j -Timeout $timeoutSeconds) { $fullnamexp = Receive-Job $j }
    Remove-Job -force $j


}

if(-not($ServerName)) { throw "You must supply a value for -ServerName" }
if(-not($certName)) { throw "You must supply a value for -certName" }

SetupHostsFile -PuppetServername $ServerName -puppetServerAddress $puppetServerAddress
InstallPuppetAgent
ConfigurePuppetAgent -ServerName $ServerName -myFQDN $certName
RunPuppet -ServerName $ServerName -timeoutSeconds 300

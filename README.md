# powershell-scripts

This repository contains various Powershell scripts:

* [Set-Fqdn.ps1](Set-Fqdn.ps1): set computer name and DNS domain to ensure the Puppet's $::fqdn fact is reasonable
* [bootstrap_windows.ps1](bootstrap_windows.ps1): install Puppet Agent on a Windows node

Each script has its own help with the usage details.
 
# Joining Windows nodes to a Puppetmaster

Typically you'd run the following in an elevated Powershell prompt to join a
Windows node to a Puppetmaster:

    Set-ExecutionPolicy -ExecutionPolicy unrestricted
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Then start a new prompt to update PATH:

    choco install git

Then start new prompt again for the same reason:

    git clone https://github.com/Puppet-Finland/powershell-scripts.git
    cd powershell-scripts
    .\Set-Fqdn.ps1 -Hostname server -Domain example.org
    .\bootstrap_windows.ps1 -Certname server.example.org -Servername puppet.example.org -PuppetServerAddress 10.10.50.1

Then sign the CSR on the Puppetmaster and you're done.

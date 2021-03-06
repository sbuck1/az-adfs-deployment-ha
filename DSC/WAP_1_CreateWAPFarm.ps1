Configuration Main
{
    Param 
    ( 
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ADFSSvcCreds,
        
        [Parameter(Mandatory)]
        [string]$PFXFilePath,

        [Parameter(Mandatory)]
        [string]$PFXThumbprint,

        [Parameter(Mandatory)]
        [string]$RootCAFilePath,

        [Parameter(Mandatory)]
        [string]$RootCAThumbprint,

        [Parameter(Mandatory)]
        [string]$ADFSLoadBalancerAddress,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$PFXPassword,

        [Parameter(Mandatory)]
        [string]$ADFSUrl,

        [Parameter(Mandatory)]
        [string]$PrimaryADFSIPAddress,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCertificate, NetworkingDsc
    
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    Node localhost
    {
        LocalConfigurationManager            
        {            
            DebugMode = 'All'
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true
        }

	    WindowsFeature WebAppProxy
        {
            Ensure = "Present"
            Name = "Web-Application-Proxy"
        }

        WindowsFeature Tools 
        {
            Ensure = "Present"
            Name = "RSAT-RemoteAccess"
            IncludeAllSubFeature = $true
        }

        WindowsFeature MoreTools 
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
            IncludeAllSubFeature = $true
        }

        WindowsFeature Telnet
        {
            Ensure = "Present"
            Name = "Telnet-Client"
        }
        HostsFile HostsFileAddEntry
        {
            HostName  = $ADFSUrl
            IPAddress = $PrimaryADFSIPAddress
            Ensure    = 'Present'
        }
        File ADFSPFXFile
        {
            DestinationPath = "C:\Install\certificate.pfx"
            Credential = $ADFSSvcCreds
            Force = $True
            SourcePath = $PFXFilePath
            Type = "File"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]WebAppProxy"
        }
        File ADFSRootCAFile
        {
            DestinationPath = "C:\Install\Root.cer"
            Credential = $ADFSSvcCreds
            Force = $True
            SourcePath = $RootCAFilePath
            Type = "File"
            Ensure = "Present"
            DependsOn = "[WindowsFeature]WebAppProxy"
        }
        xPfxImport ADFSCert
        {
            Thumbprint = $PFXThumbprint
            Path       = "C:\Install\certificate.pfx"
            Location   = 'LocalMachine'
            Store      = 'My'
            Credential = $PFXPassword
            DependsOn = '[File]ADFSPFXFile'
        }
        xCertificateImport RootCACert
        {
            Thumbprint = $RootCAThumbprint
            Path       = "C:\Install\Root.cer"
            Location   = 'LocalMachine'
            Store      = 'Root'
            DependsOn = '[File]ADFSRootCAFile'
        }
        Script Reboot
        {
            TestScript = {
            return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                    # Insert a delay before the reboot, otherwise the machine will be stuck in a reboot cycle
                    Start-Sleep -Seconds (5*60)
                    New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                    $global:DSCMachineStatus = 1 
                }
            GetScript = { return @{result = 'result'}}
            DependsOn = @("[xPfxImport]ADFSCert",
                          "[xCertificateImport]RootCACert",
                          "[HostsFile]HostsFileAddEntry")
        }
        Script CreateWAPFarm
        {
            SetScript = {
                Import-Module webapplicationproxy
                Install-WebApplicationProxy `
			        -FederationServiceTrustCredential $Using:ADFSSvcCreds `
                    -CertificateThumbprint $Using:PFXThumbprint`
                    -FederationServiceName $Using:ADFSUrl -ErrorAction Stop
            }
            TestScript = {
                $AdfsService = Get-Service adfssrv
                if($AdfsService.Status -eq "Running"){return $True}
                else{return $False}
               
            }
            GetScript = {
                $AdfsService = Get-Service adfssrv
                return @{Result = $AdfsService}
            }
            DependsOn = "[Script]Reboot"
        }

    }
    
}

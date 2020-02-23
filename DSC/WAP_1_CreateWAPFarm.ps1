Configuration Main
{
    Param 
    ( 
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdminCreds,

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
        [System.Management.Automation.PSCredential]$PFXPassword,

        [Parameter(Mandatory)]
        [string]$ADFSUrl,

        [Parameter(Mandatory)]
        [string]$PrimaryADFSServer,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCertificate
    
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
        File ADFSPFXFile
        {
            DestinationPath = "C:\Install\certificate.pfx"
            Credential = $AdminCreds
            Force = $True
            SourcePath = $PFXFilePath
            Type = "File"
            Ensure = "Present"
        }
        File ADFSRootCAFile
        {
            DestinationPath = "C:\Install\Root.cer"
            Credential = $AdminCreds
            Force = $True
            SourcePath = $RootCAFilePath
            Type = "File"
            Ensure = "Present"
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
        Script CreateWAPFarm
        {
            SetScript = {
                
                
            }
            TestScript = {
               
               
            }
            GetScript = {
                
            }
            DependsOn = @("[xPfxImport]ADFSCert",
                          "[xCertificateImport]RootCACert")
        }

    }
    
}
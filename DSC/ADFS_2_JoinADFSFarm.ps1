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
        [System.Management.Automation.PSCredential]$PFXPassword,

        [Parameter(Mandatory)]
        [string]$ADFSUrl,
        
        [Parameter(Mandatory)]
        [string]$PrimaryADFSServer,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCertificate, AdfsDsc

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name MSOnline -Force
    Install-Module -Name AzureAD -Force
    Install-Module -Name AzureADPreview -AllowClobber -Force

    Node localhost
    {
        LocalConfigurationManager            
        {            
            DebugMode = 'All'
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true
        }
        WindowsFeature installADFS  #install ADFS
        {
            Ensure = "Present"
            Name   = "ADFS-Federation"
        }
        xPfxImport ADFSCert
        {
            Thumbprint = $PFXThumbprint
            Path       = $PFXFilePath
            Location   = 'LocalMachine'
            Store      = 'My'
            Credential = $PFXPassword
            DependsOn = '[WindowsFeature]installADFS'
        }
        AdfsFarmNode JoinADFSFarm
        {
            FederationServiceName    = $ADFSUrl
            CertificateThumbprint    = $PFXThumbprint
            ServiceAccountCredential = $ADFSSvcCreds
            Credential               = $AdminCreds
            PrimaryComputerName      = $PrimaryADFSServer
            DependsOn = '[xPfxImport]ADFSCert'
        }
    }
}

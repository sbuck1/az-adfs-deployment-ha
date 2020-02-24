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
        
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCertificate
    
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
        }
        Script CreateADFSFarm
        {
            SetScript = {
                Import-Module ADFS -ErrorAction SilentlyContinue
                Install-AdfsFarm `
                    -Credential $Using:AdminCreds `
                    -CertificateThumbprint $Using:PFXThumbprint `
                    -FederationServiceName $Using:ADFSUrl `
                    -FederationServiceDisplayName "ADFS" `
                    -ServiceAccountCredential $Using:ADFSSvcCreds `
                    -OverwriteConfiguration
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
            DependsOn = '[xPfxImport]ADFSCert'
        }

    }
}

#
# Module manifest for module 'Pode'
#
# Generated by: Matthew Kelly (Badgerati)
#
# Generated on: 28/11/2017
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'Pode.psm1'

    # Version number of this module.
    ModuleVersion = '$version$'

    # ID used to uniquely identify this module
    GUID = 'e3ea217c-fc3d-406b-95d5-4304ab06c6af'

    # Author of this module
    Author = 'Matthew Kelly (Badgerati)'

    # Copyright statement for this module
    Copyright = 'Copyright (c) 2017 Matthew Kelly (Badgerati), licensed under the MIT License.'

    # Description of the functionality provided by this module
    Description = 'Pode is a PowerShell web framework that runs HTTP/TCP listeners on a specific port, allowing you to host REST APIs, Web Pages and SMTP servers'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '3.0'

    # Functions to export from this Module
    FunctionsToExport = @(
        'Route',
        'Get-PodeRoute',
        'Add-PodeTcpHandler',
        'Get-PodeTcpHandler',
        'Get-SmtpEmail',
        'Read-FromTcpStream',
        'Server',
        'Engine',
        'Start-SmtpServer',
        'Start-TcpServer',
        'Start-WebServer',
        'Write-HtmlResponse',
        'Write-HtmlResponseFromFile',
        'Write-JsonResponse',
        'Write-JsonResponseFromFile',
        'Write-ToResponse',
        'Write-ToResponseFromFile',
        'Write-ToTcpStream',
        'Write-ViewResponse',
        'Write-XmlResponse',
        'Write-XmlResponseFromFile',
        'Pode'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('powershell', 'web', 'server', 'http', 'listener', 'rest', 'api', 'tcp', 'smtp', 'websites',
                'powershell-core', 'windows', 'unix', 'linux', 'pode', 'PSEdition_Core')

            # A URL to the license for this module.
            LicenseUri = 'https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Badgerati/Pode'

        }
    }
}
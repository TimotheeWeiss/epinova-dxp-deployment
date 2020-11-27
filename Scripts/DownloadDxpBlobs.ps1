﻿[CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string] $clientKey = "",
        [Parameter(Mandatory=$false)]
        [string] $clientSecret = "",
        [Parameter(Mandatory=$false)]
        [string] $projectId = "",
        [Parameter(Mandatory=$false)]
        [string] $environment = "Integration", #Integration | Preproduction | Production
        [Parameter(Mandatory=$false)]
        [string] $downloadFolder = "d:\downloads",
        [Parameter(Mandatory=$false)]
        [int] $maxFilesToDownload = 0, # 0=All, 100=Max 100 downloads
        [Parameter(Mandatory=$false)]
        [string] $container = "Blobs",  #AppLogs | WebLogs | Blobs
        [Parameter(Mandatory=$false)]
        [bool] $overwriteExistingFiles = $true,
        [Parameter(Mandatory=$false)]
        [int] $retentionHours = 2
    )

####################################################################################


function Test-IsGuid
{
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$ObjectGuid
	)
	
	# Define verification regex
	[regex]$guidRegex = '(?im)^[{(]?[0-9A-F]{8}[-]?(?:[0-9A-F]{4}[-]?){3}[0-9A-F]{12}[)}]?$'

	# Check guid against regex
	return $ObjectGuid -match $guidRegex
}

function WriteInfo() {
    $version = Get-Host | Select-Object Version
    Write-Host $version
}

function ImportAzureStorageModule {
    $azModuleLoaded = Get-Module -Name "Az.Storage"

    if (-not ($azureModuleLoaded -or $azModuleLoaded)) {
        try {
            $null = Import-Module -Name "Az.Storage" -ErrorAction Stop
            $azModuleLoaded = $true
        }
        catch {
            Write-Verbose "Tried to find 'Az.Storage', module couldn't be imported."
        }
    }

    if ($azModuleLoaded) {
        "Az"
    }
    else {
        throw "'Az.Storage' module is required to run this cmdlet."
    }
}

function AddTlsSecurityProtocolSupport {
    <#
    .SYNOPSIS
    This helper function adds support for TLS protocol 1.1 and/or TLS 1.2

    .DESCRIPTION
    This helper function adds support for TLS protocol 1.1 and/or TLS 1.2

    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [Bool] $EnableTls11 = $true,
        [Parameter(Mandatory=$false)]
        [Bool] $EnableTls12 = $true
    )

    # Add support for TLS 1.1 and TLS 1.2
    if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls11) -AND $EnableTls11) {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls11
    }

    if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12) -AND $EnableTls12) {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }
}

function Join-Parts {
    param
    (
        $Parts = $null,
        $Separator = ''
    )

    ($Parts | ? { $_ } | % { ([string]$_).trim($Separator) } | ? { $_ } ) -join $Separator 
}

    ####################################################################################

    Write-Host "Inputs:"
    Write-Host "ClientKey: $clientKey"
    Write-Host "ClientSecret: **** (it is a secret...)"
    Write-Host "ProjectId: $projectId"
    Write-Host "Environment: $environment"
    Write-Host "DownloadFolder: $downloadFolder"
    Write-Host "MaxFilesToDownload: $maxFilesToDownload"
    Write-Host "Container: $container"
    Write-Host "OverwriteExistingFiles: $overwriteExistingFiles"
    Write-Host "RetentionHours: $retentionHours"

    #. "$PSScriptRoot\Helper.ps1"
    WriteInfo

    #Check values/params
    if ((Test-IsGuid -ObjectGuid $projectId) -ne $true){
        Write-Error "The provided ProjectId is not a guid value."
        exit
    }

    if ((Test-Path $downloadFolder -PathType Container) -eq $false) {
        Write-Error "Download folder $downloadFolder does not exist."
        exit
    }

    if ($environment -eq "Integration" -or $environment -eq "Preproduction" -or $environment -eq "Production") {
        Write-Host "Environment param ok."
    }
    else {
        Write-Error "The environment $environment that you have specified does not exist. Ok environments: Integration | Preproduction | Production"
        exit
    }

    if ($container -eq "AppLogs"){
        $container = "azure-application-logs"
    } elseif ($container -eq "WebLogs"){
        $container = "azure-web-logs"
    } elseif ($container -eq "Blobs"){
        $container = "mysitemedia"
    }else{
        Write-Error "The container $container that you have specified does not exist. Ok containers: AppLogs | WebLogs | Blobs"
        exit
    } 

    if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
        Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
            'Az modules installed at the same time is not supported.')
    } else {
        Install-Module -Name Az -AllowClobber -Scope CurrentUser
    }

    if (-not (Get-Module -Name EpiCloud -ListAvailable)) {
        Install-Module EpiCloud -Scope CurrentUser -Force
    }

    try {
        Connect-EpiCloud -ClientKey $clientKey -ClientSecret $clientSecret
    }
    catch {
        Write-Error "Could not connect to EpiCload API with specified ClientKey/ClientSecret"
        exit
    }
    
    $storageContainerSplat = @{
        ProjectId          = $projectId
        Environment = $environment
    }

    try {
        $containerResult = Get-EpiStorageContainer @storageContainerSplat
    }
    catch {
        Write-Error "Could not get storage container information from Epi. Make sure you have specified correct ProjectId/Environment"
        exit
    }
    #$containerResult
    #Write-Host $containerResult
    #$containerResult.storageContainers
    #Write-Host $containerResult.storageContainers

    if ($null -eq $containerResult){
        Write-Error "Could not get Epi DXP storage containers. Make sure you have specified correct ProjectId/Environment"
        exit
    }


    $linkSplat = @{
        ProjectId          = $projectId
        Environment = $environment
        StorageContainer = $containerResult.storageContainers
        RetentionHours = $retentionHours
    }

    $linkResult = Get-EpiStorageContainerSasLink @linkSplat

    #$linkResult

    #Write-Host $linkResult

    foreach ($link in $linkResult){
        if ($link.containerName -eq $container) {

            Write-Host "Sas link: $($link.sasLink)"

            $fullSasLink = $link.sasLink
            $fullSasLink -match "https:\/\/(.*).blob.core"
            $storageAccountName = $Matches[1]
            Write-Host "StorageAccountName: $storageAccountName"

            $fullSasLink -match "(\?.*)"
            $sasToken = $Matches[0]
            Write-Host "SAS token: $sasToken"
        }
    }
    
    if ($null -eq $sasToken) {
        Write-Error "Did not found container $container in the list."
        exit
    }


AddTlsSecurityProtocolSupport

$azureModuleType = ImportAzureStorageModule

$ctx = New-AzStorageContext -StorageAccountName $storageAccountName -SASToken $sasToken -ErrorAction Stop

if ($null -eq $ctx){
    Write-Error "No context. The provided SASToken is not valid."
    exit
}
else {
    Write-Host "Found $($blobContents.Length) BlobContent."

    if ($maxFilesToDownload -eq 0) {
        $maxFilesToDownload = [int]$blobContents.Length
    }

    $blobContents=Get-AzStorageBlob -Container $container  -Context $ctx | Sort-Object -Property LastModified -Descending
    #$itterator = 1
    $downloadedFiles = 0
    foreach($blobContent in $blobContents)  
    {  
        if ($downloadedFiles -ge $maxFilesToDownload){
            Write-Host "Hit max files to download ($maxFilesToDownload)"
            break
        }

       $filePath = Join-Parts -Separator '\' -Parts $downloadFolder, $blobContent.Name
       $fileExist = Test-Path $filePath -PathType Leaf

       if ($fileExist -eq $false -or $true -eq $overwriteExistingFiles){
            ## Download the blob content 
            Write-Host "Download #$($downloadedFiles + 1) - $($blobContent.Name) $(if ($fileExist -eq $true) {"overwrite"} else {"to"}) $filePath" 
            Get-AzStorageBlobContent -Container $container  -Context $ctx -Blob $blobContent.Name -Destination $downloadFolder -Force  
            $downloadedFiles++
       }
       else
       {
            Write-Host "File exist on disc: $filePath." 
       }

        $procentage = [int](($downloadedFiles / $maxFilesToDownload) * 100)
        Write-Progress -Activity "Download files" -Status "$procentage% Complete:" -PercentComplete $procentage;

        #$itterator++
    }
}

    ####################################################################################

    Write-Host "---THE END---"
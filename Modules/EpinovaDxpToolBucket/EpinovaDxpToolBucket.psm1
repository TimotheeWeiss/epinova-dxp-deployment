<#


.DESCRIPTION
    Help functions for Epinova DXP vs Azure Portal.
#>

Set-StrictMode -Version Latest

# PRIVATE METHODS
function Test-IsGuid {
        <#
    .SYNOPSIS
        Test a GUID.

    .DESCRIPTION
        Test a specified GUID and return true/false if it is valid GUID.

    .PARAMETER ObjectGuid
        The GUID that you want to test.

    .EXAMPLE
        Test-IsGuid -ObjectGuid $projectId

        Test if the value in the parameter $projectId is a valid GUID or not.
    #>
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

function Add-TlsSecurityProtocolSupport {
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

function Test-DownloadFolder {
    <#
    .SYNOPSIS
        Test the downloadfolder if it exist.

    .DESCRIPTION
        Test the downloadfolder if it exist.

    .PARAMETER DownloadFolder
        The provided folder where the blobs will be downloaded.

    .EXAMPLE
        Test-DownloadFolder -DownloadFolder $DownloadFolder

    #>
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$DownloadFolder
	)
    if ((Test-Path $DownloadFolder -PathType Container) -eq $false) {
        Write-Error "Download folder $DownloadFolder does not exist."
        exit
    }
}

function Test-EnvironmentParam{
    <#
    .SYNOPSIS
        ...

    .DESCRIPTION
        ...

    .PARAMETER Environment
        ...

    .EXAMPLE
        Test-EnvironmentParam -Environment $Environment

    #>
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Environment
	)    
    
    if ($Environment -eq "Integration" -or $Environment -eq "Preproduction" -or $Environment -eq "Production") {
        Write-Host "Environment param ok."
    }
    else {
        Write-Error "The environment $Environment that you have specified does not exist. Ok environments: Integration | Preproduction | Production"
        exit
    }
}

function Test-DatabaseName{
    <#
    .SYNOPSIS
        Test that the database name is correct.

    .DESCRIPTION
        Test that the database name is correct.

    .PARAMETER DatabaseName
        The database name that you want to test.

    .EXAMPLE
        Test-DatabaseName -DatabaseName $DatabaseName

    #>
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$DatabaseName
	)

    if ($databaseName -eq "epicms" -or $databaseName -eq "epicommerce") {
        Write-Host "DatabaseName param ok."
    }
    else {
        Write-Error "The database $databaseName that you have specified is not valid. Ok databaseName: epicms | epicommerce"
        exit
    } 
}

function Test-ContainerName{
    <#
    .SYNOPSIS
        Test if the container exist and if not it will figure out a container to use..

    .DESCRIPTION
        Test if the container exist and if not it will figure out a container to use..

    .PARAMETER Container
        The shortname of the container.

    .EXAMPLE
        Format-ContainerName -Container $Container

    #>
	[OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true)]
		[object]$Containers,
		[Parameter(Mandatory = $true)]
		[string]$Container
	)  

    if ($Container -eq "AppLogs"){
        $Container = "azure-application-logs"
    } elseif ($Container -eq "WebLogs"){
        $Container = "azure-web-logs"
    } elseif ($Container -eq "Blobs"){
        $Container = "mysitemedia"
    } 

    if ($false -eq $Containers.storageContainers.Contains($Container))
    #if ($false -eq $Containers.Contains($Container))
    {
        Write-Host "Containers does not contain $Container. Will try to figure out the correct one."
        Write-Host "Found the following containers for your project:"
        Write-Host "---------------------------------------------------"
        foreach ($tempContainer in $Containers.storageContainers){
        #foreach ($tempContainer in $Containers){
            Write-Host "$tempContainer"
        }
        Write-Host "---------------------------------------------------"
        if ($Container -eq "mysitemedia" -and $Containers.storageContainers.Length -eq 3) {
        #if ($Container -eq "mysitemedia" -and $Containers.Length -eq 3) {
            $exclude = @("azure-application-logs", "azure-web-logs")
            $lastContainer = $Containers.storageContainers | Where-Object { $_ -notin $exclude }
            #$lastContainer = $Containers | Where-Object { $_ -notin $exclude }
            if ($lastContainer.Length -ne 0) {
                $Container = $lastContainer
                Write-Host "Found '$Container' and going to use that as the blob container."
            } else {
                Write-Host "After trying to figure out which is the blob container. We still can not find it."
                Write-Error "Expected blob container '$Container' but we can not find it. Check the specified container above and try to specify one of them."
                exit
            }
        } else {
            if ($Container -eq "azure-application-logs" -or $Container -eq "azure-web-logs"){
                Write-Error "Expected log container '$Container' but we could not find it."
            } else {
                Write-Error "Expected container '$Container' but we can not find it. Check the found containers above and try to specify one of them as param -container."
            }
            exit
        }
    }

    return $Container
}

function Import-Az{
    <#
    .SYNOPSIS
        Install-Module Az.

    .DESCRIPTION
        Install-Module Az.

    .EXAMPLE
        Import-Az
    #>
    if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-Module -Name AzureRM -ListAvailable)) {
        Write-Warning -Message ('Az module not installed. Having both the AzureRM and ' +
            'Az modules installed at the same time is not supported.')
    } else {
        Install-Module -Name Az -AllowClobber -Scope CurrentUser
    }
}

 function Import-EpiCloud{
    <#
    .SYNOPSIS
        Import module EpiCloud.

    .DESCRIPTION
        Import module EpiCloud.

    .EXAMPLE
        Import-EpiCloud
    #>
    if (-not (Get-Module -Name EpiCloud -ListAvailable)) {
        Install-Module EpiCloud -Scope CurrentUser -Force
    } else {
        Write-Host "EpiCloud is installed."
    }
}

function Get-StorageAccountName{
    <#
    .SYNOPSIS
        Get StorageAccountName from a SAS link.

    .DESCRIPTION
        Get StorageAccountName from a SAS link.
        The SasLink you will get by using Get-DxpStorageContainerSasLink

    .PARAMETER SasLink
        The SasLink that contain the information about StorageAccountName.

    .EXAMPLE
        Get-StorageAccountName -SasLink $sasLink
    #>
    [OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true)]
		[object]$SasLink
	)
	
    $fullSasLink = $SasLink.sasLink
    $fullSasLink -match "https:\/\/(.*).blob.core" | Out-Null
    $storageAccountName = $Matches[1]

    Write-Host "StorageAccountName : $storageAccountName"

    return $storageAccountName
}

function Get-SasToken{
    <#
    .SYNOPSIS
        Get the SasToken from a SAS link.

    .DESCRIPTION
        Get the SasToken from a SAS link.
        The SasLink you will get by using Get-DxpStorageContainerSasLink

    .PARAMETER SasLink
        The SasLink that contain the information about the Sas token.

    .EXAMPLE
        Get-SasToken -SasLink $sasLink
    #>
    [OutputType([string])]
	param
	(
		[Parameter(Mandatory = $true)]
		[object]$SasLink
	)
	
    $fullSasLink = $SasLink.sasLink
    $fullSasLink -match "(\?.*)" | Out-Null
    $sasToken = $Matches[0]

    if ($null -eq $sasToken -or $sasToken.Length -eq 0) {
        Write-Warning "Did not found container $container in the list. Look in the log and see if your blob container have another name then mysitemedia. If so, specify that name as param -container. Example: Ignore container: projectname-assets. Then set -container 'projectname-assets'"
        exit
    }

    Write-Host "SAS token          : $sasToken"

    return $sasToken
}

function Join-Parts {
    <#
    .SYNOPSIS
        Join parts.

    .DESCRIPTION
        Join parts. Used for creating a URI for example

    .PARAMETER Parts
        Array of string that should be join.

    .PARAMETER Separator
        The separator character that should join the parts.

    .EXAMPLE
        $filePath = Join-Parts -Separator '\' -Parts $DownloadFolder, $blobContent.Name
        Result 'c:\temp\myblob.txt'
    #>
    [OutputType([string])]
    param
    (
        $Parts = $null,
        [string]$Separator = ''
    )

    ($Parts | Where-Object { $_ } | ForEach-Object { ([string]$_).trim($Separator) } | Where-Object { $_ } ) -join $Separator 
}

function Get-DxpDateTimeStamp{
    <#
    .SYNOPSIS
        Create DateTime stamp in correct format.

    .DESCRIPTION
        Create DateTime stamp in yyyy-MM-ddTHH:mm:ss format.

    .EXAMPLE
        Get-DxpDateTimeStamp

        You will get the DateTime now in the format ex: '2021-02-20T14:34:22'.
    #>
    $dateTimeNow = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    return $dateTimeNow
}

function Invoke-DxpDatabaseExportProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ClientKey,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ClientSecret,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ExportId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Environment,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ExpectedStatus,

        [Parameter(Mandatory = $true)]
        [int] $Timeout
    )
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $sw.Start()
    $currentStatus = ""
    $iterator = 0
    $status = $null
    while ($currentStatus -ne $expectedStatus) {
        $status = Get-EpiDatabaseExport -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Id $ExportId -Environment $Environment -DatabaseName $DatabaseName
        $currentStatus = $status.status
        if ($iterator % 6 -eq 0) {
            Write-Host "Database backup status: $($currentStatus). ElapsedSeconds: $($sw.Elapsed.TotalSeconds)"
        }
        if ($currentStatus -ne $ExpectedStatus) {
            Start-Sleep 10
        }
        if ($sw.Elapsed.TotalSeconds -ge $timeout) { break }
        if ($currentStatus -eq $ExpectedStatus) { break }
        $iterator++
    }

    $sw.Stop()
    Write-Host "Stopped iteration after $($sw.Elapsed.TotalSeconds) seconds."

    #$status = Get-EpiDatabaseExport -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Id $ExportId -Environment $Environment -DatabaseName $DatabaseName
    if ($null -ne $status){
        Write-Host "################################################"
        Write-Host "Database export:"
        Write-Host "Status:       $($status.status)"
        Write-Host "BacpacName:   $($status.bacpacName)"
        Write-Host "DownloadLink: $($status.downloadLink)"
    }
    return $status
}

function Test-DxpProjectId {
    <#
    .SYNOPSIS
        Test a DXP project id.

    .DESCRIPTION
        Test a specified project Id if it is a valid GUID and return true/false.

    .PARAMETER ProjectId
        The provided ProjectId that you want to test.

    .EXAMPLE
        Test-DxpProjectId -ProjectId $projectId

        Test if the value in the parameter $projectId is a valid DXP project id.
    #>
	[OutputType([bool])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$ProjectId
	)
	
    if ((Test-IsGuid -ObjectGuid $ProjectId) -ne $true){
        Write-Error "The provided ProjectId is not a guid value."
        exit
    } else {
        Write-Host "ProjectId is a GUID."
    }
}

function Import-AzureStorageModule {
    <#
    .SYNOPSIS
        Load module Az.Storage.

    .DESCRIPTION
        Load module Az.Storage.

    .EXAMPLE
        Import-AzureStorageModule

    #>
    $azureModuleLoaded = $false
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
        Write-Host "Az module loaded."
    }
    else {
        Write-Error "'Az.Storage' module is required to run this cmdlet."
        exit
    }
}

function Write-DxpHostVersion() {
    <#
    .SYNOPSIS
        Write the PowerShell host version in the host.

    .DESCRIPTION
        Write the PowerShell host version in the host.

    .EXAMPLE
        Write-DxpHostVersion

        Will print out the PowerShell host version in the host. Ex: @{Version=5.1.14393.3866}
    #>
    $version = Get-Host | Select-Object Version
    Write-Host $version
}

function Connect-DxpEpiCloud{
    <#
    .SYNOPSIS
        Adds credentials (ClientKey and ClientSecret) for all functions
        in EpiCloud module to be used during the session/context.

    .DESCRIPTION
        Connect to the EpiCloud.

    .PARAMETER ClientKey
        The client key used to access the project.

    .PARAMETER ClientSecret
        The client secret used to access the project.

    .PARAMETER ProjectId
        The id of the DXP project.

    .EXAMPLE
        Connect-DxpEpiCloud -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId

    .EXAMPLE
        Connect-DxpEpiCloud -ClientKey '644b6926-39b1-42a1-93d6-3771cdc4a04e' -ClientSecret '644b6926-39b1fasrehyjtye-42a1-93d6-3771cdc4asasda04e' -ProjectId '644b6926-39b1-42a1-93d6-3771cdc4a04e'

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientSecret,

        [Parameter(Mandatory = $true)]
        [String] $ProjectId
    )
    Connect-EpiCloud -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId
    Write-Host "Connected to DXP Project $ProjectId"
}

function Invoke-DxpProgress {
    <#
    .SYNOPSIS
        Write the progress of a operation in the Optimizely (formerly known as Episerver) DXP environment to the host.

    .DESCRIPTION
        Write the progress of a operation in the Optimizely (formerly known as Episerver) DXP environment to the host.

    .PARAMETER projectId
        Project id for the project in Optimizely (formerly known as Episerver) DXP.

    .PARAMETER deploymentId
        Deployment id for the specific deployment in Optimizely (formerly known as Episerver) DXP that you want to show the progress for.

    .PARAMETER percentComplete
        The initialized percentComplete value that we got from the invoke of the operation.

    .PARAMETER expectedStatus
        The expectedStatus that the deployment should get when done/before timeout.

    .PARAMETER timeout
        The maximum time that the progress should run. When the script has timeout if will stop.

    .EXAMPLE
        $status = Invoke-DxpProgress -projectid $projectId -deploymentId $deploymentId -percentComplete $percentComplete -expectedStatus $expectedStatus -timeout $timeout

    .EXAMPLE
        $status = Invoke-DxpProgress -projectid '644b6926-39b1-42a1-93d6-3771cdc4a04e' -deploymentId '817b5df3-21cd-4080-adbd-6c211b71f34d' -percentComplete 0 -expectedStatus 'Success' -timeout 1800

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $projectId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $deploymentId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [int] $percentComplete,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $expectedStatus,
        [Parameter(Mandatory = $true)]
        [int] $timeout
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()
    $sw.Start()
    while ($percentComplete -le 100) {
        $status = Get-EpiDeployment -ProjectId $projectId -Id $deploymentId
        if ($percentComplete -ne $status.percentComplete) {
            $percentComplete = $status.percentComplete
            Write-Host $percentComplete "%. Status: $($status.status). ElapsedSeconds: $($sw.Elapsed.TotalSeconds)"
        }
        if ($percentComplete -le 100 -or $status.status -ne $expectedStatus) {
            Start-Sleep 5
        }
        if ($sw.Elapsed.TotalSeconds -ge $timeout) { break }
        if ($status.percentComplete -eq 100 -and $status.status -eq $expectedStatus) { break }
    }

    $sw.Stop()
    Write-Host "Stopped iteration after $($sw.Elapsed.TotalSeconds) seconds."

    $status = Get-EpiDeployment -ProjectId $projectId -Id $deploymentId
    $status
    return $status
}

function Get-DxpStorageContainerSasLink{
    <#
    .SYNOPSIS
        ...

    .DESCRIPTION
        ...

    .PARAMETER ClientKey
        The client key used to access the project.

    .PARAMETER ClientSecret
        The client secret used to access the project.

    .PARAMETER ProjectId
        The id of the DXP project.

    .PARAMETER Environment
        The environment where we should check for storage containers.

    .PARAMETER Containers
        List of containers that we should look for the one that match the next parameter Container.

    .PARAMETER Container
        The name of the container that you want. If it does not exist it will try ti figure out which container you want.

    .EXAMPLE
        Get-DxpStorageContainerSasLink -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment -Containers $Containers -Container $Container -RetentionHours $RetentionHours

    .EXAMPLE
        Get-DxpStorageContainerSasLink -ClientKey '644b6926-39b1-42a1-93d6-3771cdc4a04e' -ClientSecret '644b6926-39b1fasrehyjtye-42a1-93d6-3771cdc4asasda04e'-ProjectId '644b6926-39b1-42a1-93d6-3771cdc4a04e' -Environment 'Integration' -Containers $Containers -Container "mysitemedia" -RetentionHours 2

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientSecret,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Environment,

        [Parameter(Mandatory = $false)]
        [object] $Containers,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Container,

        [Parameter(Mandatory = $false)]
        [int] $RetentionHours = 2

    )

    if ($null -eq $Containers){
        $Containers = Get-DxpStorageContainers -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment
    }

    $linkSplat = @{
        ClientKey = $ClientKey
        ClientSecret = $ClientSecret
        ProjectId = $ProjectId
        Environment = $Environment
        StorageContainer = $Containers.storageContainers
        RetentionHours = $RetentionHours
    }

    $linkResult = Get-EpiStorageContainerSasLink @linkSplat

    $sasLink = $null
    foreach ($link in $linkResult){
        if ($link.containerName -eq $Container) {
            Write-Host "Found Sas link for container   : $Container"
            $sasLink = $link
        } else {
            Write-Host "Ignore container   : $($link.containerName)"
        }
    }

    return $sasLink
}

function Invoke-DownloadStorageAccountFiles{
    <#
    .SYNOPSIS
        Download files from the specified storageaccount and specified container.

    .DESCRIPTION
        Download files from the specified storageaccount and specified container.

    .PARAMETER StorageAccountName
        The storage account name the you want to download from.

    .PARAMETER SasToken
        SAS token needed for the access to the storage account.

    .PARAMETER DownloadFolder
        The folder on disc where you want to download your files.

    .PARAMETER Container
        List of containers that we should look for the one that match the next parameter Container.

    .PARAMETER MaxFilesToDownload
        The max number of files you want to download. 0=All. X=Download X number of files.

    .PARAMETER OverwriteExistingFiles
        True/False if you want to overwrite if there is any existing files in the download folder.

    .EXAMPLE
        Invoke-DownloadStorageAccountFiles -StorageAccountName $StorageAccountName -SasToken $SasToken -DownloadFolder $DownloadFolder -Container $Container -MaxFilesToDownload $MaxFilesToDownload -OverwriteExistingFiles $OverwriteExistingFiles

    .EXAMPLE
        Invoke-DownloadStorageAccountFiles -StorageAccountName "exxxxx012znb5inte" -SasToken "?sv=2017-04-17&sr=c&sig=RqgmOvZM%2BV4HQPAKqCm5KE5PI4ZjbnQqDaQPEQjz6gs%3D&st=2021-03-01T22%3A20%3A26Z&se=2021-03-02T00%3A20%3A26Z&sp=rl" -DownloadFolder "c:\temp" -Container "mysitemedia" -MaxFilesToDownload 100 -OverwriteExistingFiles $false

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $StorageAccountName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SasToken,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Container,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DownloadFolder,

        [Parameter(Mandatory = $false)]
        [int] $MaxFilesToDownload = 0,


        [Parameter(Mandatory = $false)]
        [bool] $OverwriteExistingFiles = $true,

        [Parameter(Mandatory = $false)]
        [int] $RetentionHours = 2

    )
    Write-Host "Invoke-DownloadStorageAccountFiles - Inputs:----"
    Write-Host "StorageAccountName:     $StorageAccountName"
    Write-Host "ClientSecret:           **** (it is a secret...)"
    Write-Host "SasToken:               $SasToken"
    Write-Host "Container:              $Container"
    Write-Host "DownloadFolder:         $DownloadFolder"
    Write-Host "MaxFilesToDownload:     $MaxFilesToDownload"
    Write-Host "OverwriteExistingFiles: $OverwriteExistingFiles"
    Write-Host "RetentionHours:         $RetentionHours"
    Write-Host "------------------------------------------------"

    $ctx = New-AzStorageContext -StorageAccountName $storageAccountName -SASToken $SasToken -ErrorAction Stop

    $ArrayList = [System.Collections.ArrayList]::new()

    if ($null -eq $ctx){
        Write-Error "No context. The provided SASToken is not valid."
        exit
    }
    else {
        $blobContents = Get-AzStorageBlob -Container $Container  -Context $ctx | Sort-Object -Property LastModified -Descending

        if ($null -eq $blobContents){
            Write-Host "Can not find any blobs in container $Container :("
            exit
        }
    
        Write-Host "Found $($blobContents.Length) BlobContent."

        if ($blobContents.Length -eq 0) {
            Write-Warning "No blob/files found in the container '$container'"
            exit
        }

        if ($MaxFilesToDownload -eq 0) {
            $MaxFilesToDownload = [int]$blobContents.Length
        }
        $downloadedFiles = 0
        
        Write-Host "---------------------------------------------------"
        foreach($blobContent in $blobContents)  
        {  
            if ($downloadedFiles -ge $MaxFilesToDownload){
                Write-Host "Hit max files to download ($MaxFilesToDownload)"
                break
            }

            $filePath = Join-Parts -Separator '\' -Parts $DownloadFolder, $blobContent.Name
            $fileExist = Test-Path $filePath -PathType Leaf

            if ($fileExist -eq $false -or $true -eq $OverwriteExistingFiles){
                ## Download the blob content 
                Write-Host "Download #$($downloadedFiles + 1) - $($blobContent.Name) $(if ($fileExist -eq $true) {"overwrite"} else {"to"}) $filePath" 
                [void]$ArrayList.Add($filePath)
                $doNothingWithThisInfo = Get-AzStorageBlobContent -Container $Container -Context $ctx -Blob $blobContent.Name -Destination $DownloadFolder -Force -AsJob
                $downloadedFiles++
            } else {
                Write-Host "File exist on disc: $filePath." 
            }

            $procentage = [int](($downloadedFiles / $maxFilesToDownload) * 100)
            Write-Progress -Activity "Download files" -Status "$procentage% complete." -PercentComplete $procentage;
        }
        Write-Progress -Activity "Download files" -Completed;
        Write-Host "---------------------------------------------------"
    }

    return $ArrayList
}

# END PRIVATE METHODS

function Get-DxpStorageContainers{
    <#
    .SYNOPSIS
        List storage containers in a DXP environment.

    .DESCRIPTION
        List storage containers in a DXP environment.

    .PARAMETER ClientKey
        The client key used to access the project.

    .PARAMETER ClientSecret
        The client secret used to access the project.

    .PARAMETER ProjectId
        The id of the DXP project.

    .PARAMETER Environment
        The environment where we should check for storage containers.

    .PARAMETER Container
        The name of the container that you want. If it does not exist it will try ti figure out which container you want.

    .EXAMPLE
        Get-DxpStorageContainers -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment

    .EXAMPLE
        Get-DxpStorageContainers -ClientKey '644b6926-39b1-42a1-93d6-3771cdc4a04e' -ClientSecret '644b6926-39b1fasrehyjtye-42a1-93d6-3771cdc4asasda04e'-ProjectId '644b6926-39b1-42a1-93d6-3771cdc4a04e' -Environment 'Integration' 

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientKey,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientSecret,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Environment
    )

    Write-Host "Get-DxpStorageContainers - Inputs:--------------"
    Write-Host "ClientKey:              $ClientKey"
    Write-Host "ClientSecret:           **** (it is a secret...)"
    Write-Host "ProjectId:              $ProjectId"
    Write-Host "Environment:            $Environment"
    Write-Host "------------------------------------------------"

    Test-DxpProjectId -ProjectId $ProjectId
    Test-EnvironmentParam -Environment $Environment

    Import-EpiCloud

    try {
        $containers = Get-EpiStorageContainer -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment
    }
    catch {
        Write-Error "Could not get storage container information from Epi. Make sure you have specified correct ProjectId/Environment"
        exit
    }

    if ($null -eq $containers){
        Write-Error "Could not get Epi DXP storage containers. Make sure you have specified correct ProjectId/Environment"
        exit
    }

    return $containers
}

function Invoke-DxpBlobsDownload{
    <#
    .SYNOPSIS
        Download DXP project blobs.

    .DESCRIPTION
        Download DXP project blobs. You can specify the environment where the blobs exist.

    .PARAMETER ClientKey
        Your DXP ClientKey that you can generate in the paas.episerver.net portal.

    .PARAMETER ClientSecret
        Your DXP ClientSecret that you can generate in the paas.episerver.net portal.

    .PARAMETER ProjectId
        The DXP project id that is related to the ClientKey/Secret.

    .PARAMETER Environment
        The environment that holds the blobs that you want to download.

    .PARAMETER DownloadFolder
        The local download folder where you want to download the blob files.

    .PARAMETER MaxFilesToDownload
        The max number of blobs you want to download. 0=All. X=The first X number of blob found in the blobs container. Order by LastModified -Descending

    .PARAMETER Container
        The type of container you want to download. 
        AppLogs=Application logs that is created by your application in the specified environment.
        WebLogs=Web logs/IIS logs that is created by your webapp in the specified environment.
        Blobs or *=The container name where your blobs are stored. At present date (2021-02-02) Optimizely (formerly known as Episerver) have no default or standard name of the blobs container. So the script will try to help you find the right one. If not it will list the containers and you will be able to rerun the script and try which one it is.

    .PARAMETER OverwriteExistingFiles
        True/False if the downloaded files should overwite existing files (if exist).

    .PARAMETER RetentionHours
        The number of hours that the SAS token used for download will be ok. Default is 2 hours. This maybe need to be raised if it take longer then 2 hours to download the files requested to download.

    .EXAMPLE
        Invoke-DxpBlobsDownload -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment -DownloadFolder $DownloadFolder -MaxFilesToDownload $MaxFilesToDownload -Container $Container -OverwriteExistingFiles $OverwriteExistingFiles -RetentionHours $RetentionHours

    .EXAMPLE
        Invoke-DxpBlobsDownload -ClientKey '644b6926-39b1-42a1-93d6-3771cdc4a04e' -ClientSecret '644b6926-39b1fasrehyjtye-42a1-93d6-3771cdc4asasda04e'-ProjectId '644b6926-39b1-42a1-93d6-3771cdc4a04e' -Environment 'Integration' -DownloadFolder "c:\temp" -MaxFilesToDownload 100 -Container "mysitemedia" -OverwriteExistingFiles $false -RetentionHours 2

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientKey,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ClientSecret,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Integration','Preproduction','Production')]
        [string] $Environment = "Integration",

        [Parameter(Mandatory=$false)]
        [string] $DownloadFolder = $PSScriptRoot, 

        [Parameter(Mandatory=$false)]
        [int] $MaxFilesToDownload = 0, # 0=All, 100=Max 100 downloads

        [Parameter(Mandatory=$false)]
        [string] $Container = "Blobs",  #AppLogs | WebLogs | Blobs

        [Parameter(Mandatory=$false)]
        [bool] $OverwriteExistingFiles = $true,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 168)]
        [int] $RetentionHours = 2

    )

    Write-Host "Invoke-DxpBlobsDownload - Inputs:-----------------"
    Write-Host "ClientKey:              $ClientKey"
    Write-Host "ClientSecret:           **** (it is a secret...)"
    Write-Host "ProjectId:              $ProjectId"
    Write-Host "Environment:            $Environment"
    Write-Host "DownloadFolder:         $DownloadFolder"
    Write-Host "MaxFilesToDownload:     $MaxFilesToDownload"
    Write-Host "Container:              $Container"
    Write-Host "OverwriteExistingFiles: $OverwriteExistingFiles"
    Write-Host "RetentionHours:         $RetentionHours"
    Write-Host "------------------------------------------------"

    Write-DxpHostVersion

    Test-DxpProjectId -ProjectId $ProjectId
    Test-DownloadFolder -DownloadFolder $DownloadFolder
    Test-EnvironmentParam -Environment $Environment

    Import-Az
    Import-EpiCloud

    #Connect-DxpEpiCloud -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId

    $containers = Get-DxpStorageContainers -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment

    $Container = Test-ContainerName -Containers $containers -Container $Container
    #$Container
    
    $sasLink = Get-DxpStorageContainerSasLink -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment -Containers $containers -Container $Container -RetentionHours $RetentionHours
    # $sasLink

    $storageAccountName = Get-StorageAccountName -SasLink $sasLink
    $sasToken = Get-SasToken -SasLink $sasLink

    Add-TlsSecurityProtocolSupport
    Import-AzureStorageModule

    $ArrayList = Invoke-DownloadStorageAccountFiles -StorageAccountName $StorageAccountName -SasToken $SasToken -DownloadFolder $DownloadFolder -Container $Container -MaxFilesToDownload $MaxFilesToDownload -OverwriteExistingFiles $OverwriteExistingFiles
    #$files = 
    #Write-Host "¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤"
    #$files | Select-Object -Last 1 | Format-Table
    #$Files | Format-Table
    #Write-Host "¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤¤"

    #$Files = $files
    return $ArrayList
}

function Invoke-DxpDatabaseDownload{
    <#
    .SYNOPSIS
        Download DXP project DB.

    .DESCRIPTION
        Download DXP project DB. You can specify the environment from where the database should be exported from.

    .PARAMETER ClientKey
        Your DXP ClientKey that you can generate in the paas.episerver.net portal.

    .PARAMETER ClientSecret
        Your DXP ClientSecret that you can generate in the paas.episerver.net portal.

    .PARAMETER ProjectId
        The DXP project id that is related to the ClientKey/Secret.

    .PARAMETER Environment
        The environment that holds the blobs that you want to download.

    .PARAMETER DatabaseName
        The database you want to download. epicms / epicommerce

    .PARAMETER DownloadFolder
        The local download folder where you want to download the DB backup file.

    .PARAMETER RetentionHours
        The number of hours that the SAS token used for download will be ok. Default is 2 hours. This maybe need to be raised if it take longer then 2 hours to download the files requested to download.

    .PARAMETER Timeout
        The number of seconds that you will let the script run until it will timeout. Default 1800 (ca 30 minutes)

    .EXAMPLE
        Invoke-DxpDatabaseDownload -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId -Environment $Environment -DatabaseName $DatabaseName -DownloadFolder $DownloadFolder -RetentionHours $RetentionHours -Timeout $Timeout

    .EXAMPLE
        Invoke-DxpDatabaseDownload -ClientKey '644b6926-39b1-42a1-93d6-3771cdc4a04e' -ClientSecret '644b6926-39b1fasrehyjtye-42a1-93d6-3771cdc4asasda04e'-ProjectId '644b6926-39b1-42a1-93d6-3771cdc4a04e' -Environment 'Integration' -DatabaseName 'epicms' -DownloadFolder "c:\temp" -RetentionHours 2 -Timeout 1800

    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ClientKey,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $ClientSecret,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ProjectId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Integration','Preproduction','Production')]
        [string] $Environment,

        [Parameter(Mandatory=$true)]
        [ValidateSet('epicms','epicommerce')]
        [string] $DatabaseName,

        [Parameter(Mandatory=$true)]
        [string] $DownloadFolder,

        [Parameter(Mandatory=$false)]
        [ValidateRange(1, 168)]
        [int] $RetentionHours = 2,

        [Parameter(Mandatory = $false)]
        [int] $Timeout = 1800
    )

    Write-Host "Invoke-DxpDatabaseDownload - Inputs:-------------"
    Write-Host "ClientKey:              $ClientKey"
    Write-Host "ClientSecret:           **** (it is a secret...)"
    Write-Host "ProjectId:              $ProjectId"
    Write-Host "Environment:            $Environment"
    Write-Host "DatabaseName:           $databaseName"
    Write-Host "DownloadFolder:         $DownloadFolder"
    Write-Host "RetentionHours:         $RetentionHours"
    Write-Host "Timeout:                $timeout"
    Write-Host "------------------------------------------------"

    Write-DxpHostVersion

    Test-DxpProjectId -ProjectId $ProjectId
    Test-DownloadFolder -DownloadFolder $DownloadFolder
    Test-EnvironmentParam -Environment $Environment
    Test-DatabaseName -DatabaseName $DatabaseName

    Import-EpiCloud

    Connect-DxpEpiCloud -ClientKey $ClientKey -ClientSecret $ClientSecret -ProjectId $ProjectId

    $exportDatabaseSplat = @{
        ClientKey      = $ClientKey
        ClientSecret   = $ClientSecret
        ProjectId      = $ProjectId
        Environment    = $Environment
        DatabaseName   = $DatabaseName
        RetentionHours = $RetentionHours
    }

    $export = Start-EpiDatabaseExport @exportDatabaseSplat
    Write-Host "Database export has started:--------------------"
    Write-Host "Id:           $($export.id)"
    Write-Host "ProjectId:    $($export.projectId)"
    Write-Host "DatabaseName: $($export.databaseName)"
    Write-Host "Environment:  $($export.environment)"
    Write-Host "Status:       $($export.status)"
    Write-Host "------------------------------------------------"

    $exportId = $export.id 

    if ($export.status -eq "InProgress") {
        $deployDateTime = Get-DxpDateTimeStamp
        Write-Host "Export $exportId started $deployDateTime."
    } else {
        Write-Error "Status is not in InProgress (Current:$($export.status)). You can not export database at this moment."
        exit
    }

    if ($export.status -eq "InProgress" -or $status.status -eq "Succeeded") {
        Write-Host "----------------PROGRESS-------------------------"
        $status = Invoke-DxpDatabaseExportProgress -ClientKey $ClientKey -ClientSecret $ClientSecret -Projectid $ProjectId -ExportId $ExportId -Environment $Environment -DatabaseName $DatabaseName -ExpectedStatus "Succeeded" -Timeout $timeout
        Write-Host "------------------------------------------------"
        $deployDateTime = Get-DxpDateTimeStamp
        Write-Host "Export $exportId ended $deployDateTime"

        if ($status.status -eq "Succeeded") {
            Write-Host "Database export $exportId has been successful."
            Write-Host "-------------DOWNLOAD----------------------------"
            Write-Host "Start download database $($status.downloadLink)"
            $filePath = Join-Parts -Separator '\' -Parts $DownloadFolder, $status.bacpacName
            Invoke-WebRequest -Uri $status.downloadLink -OutFile $filePath
            Write-Host "Download database to $filePath"
            Write-Host "------------------------------------------------"
        }
        else {
            Write-Error "The database export has not been successful or the script has timedout. CurrentStatus: $($status.status)"
            exit
        }
    }
    else {
        Write-Error "Status is not in InProgress (Current:$($export.status)). You can not export database at this moment."
        exit
    }
}

Export-ModuleMember -Function @( 'Invoke-DxpBlobsDownload', 'Invoke-DxpDatabaseDownload', 'Get-DxpStorageContainers', 'Get-DxpStorageContainerSasLink' )
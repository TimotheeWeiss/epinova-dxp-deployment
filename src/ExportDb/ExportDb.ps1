Trace-VstsEnteringInvocation $MyInvocation
$global:ErrorActionPreference = 'Continue'
$global:__vstsNoOverrideVerbose = $true

try {
    # Get all inputs for the task
    $clientKey = Get-VstsInput -Name "ClientKey" -Require -ErrorAction "Stop"
    $clientSecret = Get-VstsInput -Name "ClientSecret" -Require -ErrorAction "Stop"
    $projectId = Get-VstsInput -Name "ProjectId" -Require -ErrorAction "Stop"
    $environment = Get-VstsInput -Name "Environment" -Require -ErrorAction "Stop"
    $databaseName = Get-VstsInput -Name "DatabaseName" -Require -ErrorAction "Stop"
    $retentionHours = Get-VstsInput -Name "RetentionHours" -AsInt -Require -ErrorAction "Stop"
    $timeout = Get-VstsInput -Name "Timeout" -AsInt -Require -ErrorAction "Stop"

    # 30 min timeout
    ####################################################################################
    Write-Host "Inputs:"
    Write-Host "ClientKey: $clientKey"
    Write-Host "ClientSecret: **** (it is a secret...)"
    Write-Host "ProjectId: $projectId"
    Write-Host "Environment: $environment"
    Write-Host "DatabaseName: $databaseName"
    Write-Host "RetentionHours: $retentionHours"
    Write-Host "Timeout: $timeout"

    . "$PSScriptRoot\Helper.ps1"
    WriteInfo

    if ((Test-IsGuid -ObjectGuid $projectId) -ne $true){
        Write-Error "The provided ProjectId is not a guid value."
        exit 1
    }

    if (-not (Get-Module -Name EpiCloud -ListAvailable)) {
        $env:PSModulePath = "$PSScriptRoot\ps_modules;" + $env:PSModulePath
        Install-Module EpiCloud -Scope CurrentUser -Force
    }

    Connect-EpiCloud -ClientKey $clientKey -ClientSecret $clientSecret

    $exportDatabaseSplat = @{
        ProjectId          = $projectId
        Environment = $environment
        DatabaseName          = $databaseName
        RetentionHours = $retentionHours
    }

    $export = Start-EpiDatabaseExport @exportDatabaseSplat
    Write-Host "Database export has started:"
    Write-Host "Id: $($export.id)"
    Write-Host "ProjectId: $($export.projectId)"
    Write-Host "DatabaseName: $($export.databaseName)"
    Write-Host "Environment: $($export.environment)"
    Write-Host "Status: $($export.status)"

    $exportId = $export.id

    if ($export.status -eq "InProgress") {
        $deployDateTime = GetDateTimeStamp
        Write-Host "Export $exportId started $deployDateTime."

        $status = ExportProgress -projectid $projectId -exportId $exportId -environment $environment -databaseName $databaseName -expectedStatus "Succeeded" -timeout $timeout

        $deployDateTime = GetDateTimeStamp
        Write-Host "Export $exportId ended $deployDateTime"

        if ($status.status -eq "Succeeded") {
            Write-Host "Database export $exportId has been successful."
        }
        else {
            Write-Warning "The database export has not been successful or the script has timedout. CurrentStatus: $($status.status)"
            Write-Host "##vso[task.logissue type=error]The database export has not been successful or the script has timedout. CurrentStatus: $($status.status)"
            Write-Error "The database export has not been successful or the script has timedout. CurrentStatus: $($status.status)" -ErrorAction Stop
            exit 1
        }
    }
    else {
        Write-Warning "Status is not in InProgress (Current:$($export.status)). You can not export database at this moment."
        Write-Host "##vso[task.logissue type=error]Status is not in InProgress (Current:$($export.status)). You can not export database at this moment."
        Write-Error "Status is not in InProgress (Current:$($export.status)). You can not export database at this moment." -ErrorAction Stop
        exit 1
    }
    Write-Host "Setvariable ExportId: $exportId"
    Write-Host "##vso[task.setvariable variable=ExportId;]$($exportId)"
    Write-Host "Setvariable DbExportDownloadLink: $($status.downloadLink)"
    Write-Host "##vso[task.setvariable variable=DbExportDownloadLink;]$($status.downloadLink)"
    ####################################################################################
    Write-Host "---THE END---"

}
catch {
    Write-Verbose "Exception caught from task: $($_.Exception.ToString())"
    throw
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}


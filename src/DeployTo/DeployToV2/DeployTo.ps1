[CmdletBinding()]
Param(
    $ClientKey,
    $ClientSecret,
    $ProjectId, 
    $SourceEnvironment,
    $TargetEnvironment,
    $SourceApp,
    $UseMaintenancePage,
    $Timeout,
    $IncludeBlob,
    $IncludeDb,
    $ZeroDowntimeMode
)

try {
    # Get all inputs for the task
    $clientKey = $ClientKey
    $clientSecret = $ClientSecret
    $projectId = $ProjectId
    $sourceEnvironment = $SourceEnvironment
    $targetEnvironment = $TargetEnvironment
    $sourceApp = $SourceApp
    [Boolean]$useMaintenancePage = [System.Convert]::ToBoolean($UseMaintenancePage)
    $timeout = $Timeout
    [Boolean]$includeBlob = [System.Convert]::ToBoolean($IncludeBlob)
    [Boolean]$includeDb = [System.Convert]::ToBoolean($IncludeDb)
    $zeroDowntimeMode = $ZeroDowntimeMode


    # 30 min timeout
    ####################################################################################

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Write-Host "Inputs:"
    Write-Host "ClientKey:          $clientKey"
    Write-Host "ClientSecret:       **** (it is a secret...)"
    Write-Host "ProjectId:          $projectId"
    Write-Host "SourceEnvironment:  $sourceEnvironment"
    Write-Host "TargetEnvironment:  $targetEnvironment"
    Write-Host "SourceApp:          $sourceApp"
    Write-Host "UseMaintenancePage: $useMaintenancePage"
    Write-Host "Timeout:            $timeout"
    Write-Host "IncludeBlob:        $includeBlob"
    Write-Host "IncludeDb:          $includeDb"
    Write-Host "ZeroDowntimeMode:   $zeroDowntimeMode"

    . "$PSScriptRoot\ps_modules\EpinovaDxpDeploymentUtil.ps1"

    Mount-PsModulesPath

    Initialize-EpiCload

    Write-DxpHostVersion

    Test-DxpProjectId -ProjectId $projectId

    Connect-DxpEpiCloud -ClientKey $clientKey -ClientSecret $clientSecret -ProjectId $projectId

    $sourceApps = $sourceApp.Split(",")

    if ($null -eq $zeroDowntimeMode -or $zeroDowntimeMode -eq "" -or $zeroDowntimeMode -eq "Not specified") {
        $startEpiDeploymentSplat = @{
            ProjectId          = $projectId
            SourceEnvironment  = $sourceEnvironment
            TargetEnvironment  = $targetEnvironment
            SourceApp          = $sourceApps
            UseMaintenancePage = $useMaintenancePage
            IncludeBlob = $includeBlob
            IncludeDb = $includeDb
        }
    } else {
        $startEpiDeploymentSplat = @{
            ProjectId          = $projectId
            SourceEnvironment  = $sourceEnvironment
            TargetEnvironment  = $targetEnvironment
            SourceApp          = $sourceApps
            UseMaintenancePage = $useMaintenancePage
            IncludeBlob = $includeBlob
            IncludeDb = $includeDb
            ZeroDowntimeMode = $zeroDowntimeMode
        }
    }

    $deploy = Start-EpiDeployment @startEpiDeploymentSplat
    $deploy

    $deploymentId = $deploy.id

    if ($deploy.status -eq "InProgress") {
        $deployDateTime = Get-DxpDateTimeStamp
        Write-Host "Deploy $deploymentId started $deployDateTime."
        $percentComplete = $deploy.percentComplete
        $status = Invoke-DxpProgress -Projectid $projectId -DeploymentId $deploymentId -PercentComplete $percentComplete -ExpectedStatus "AwaitingVerification" -Timeout $timeout

        $deployDateTime = Get-DxpDateTimeStamp
        Write-Host "Deploy $deploymentId ended $deployDateTime"

        if ($status.status -eq "AwaitingVerification") {
            Write-Host "Deployment $deploymentId has been successful."
        }
        else {
            Write-Warning "The deploy has not been successful or the script has timed out. CurrentStatus: $($status.status)"
            Write-Host "##vso[task.logissue type=error]The deploy has not been successful or the script has timed out. CurrentStatus: $($status.status)"
            Write-Error "The deploy has not been successful or the script has timed out. CurrentStatus: $($status.status)" -ErrorAction Stop
            exit 1
        }
    }
    else {
        Write-Warning "Status is not in InProgress (Current:$($deploy.status)). You can not deploy at this moment."
        Write-Host "##vso[task.logissue type=error]Status is not in InProgress (Current:$($deploy.status)). You can not deploy at this moment."
        Write-Error "Status is not in InProgress (Current:$($deploy.status)). You can not deploy at this moment." -ErrorAction Stop
        exit 1
    }
    Write-Host "Setvariable DeploymentId: $deploymentId"
    Write-Host "##vso[task.setvariable variable=DeploymentId;]$($deploymentId)"

    ####################################################################################

    Write-Host "---THE END---"

}
catch {
    Write-Verbose "Exception caught from task: $($_.Exception.ToString())"
    throw
}

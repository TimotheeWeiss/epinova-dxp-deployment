Trace-VstsEnteringInvocation $MyInvocation
$global:ErrorActionPreference = 'Continue'
$global:__vstsNoOverrideVerbose = $true

try {
    # Get all inputs for the task
    $clientKey = Get-VstsInput -Name "ClientKey" -Require -ErrorAction "Stop"
    $clientSecret = Get-VstsInput -Name "ClientSecret" -Require -ErrorAction "Stop"
    $projectId = Get-VstsInput -Name "ProjectId" -Require -ErrorAction "Stop"
    $sourceEnvironment = Get-VstsInput -Name "SourceEnvironment" -Require -ErrorAction "Stop"
    $targetEnvironment = Get-VstsInput -Name "TargetEnvironment" -Require -ErrorAction "Stop"
    $sourceApp = Get-VstsInput -Name "SourceApp" -Require -ErrorAction "Stop"
    $useMaintenancePage = Get-VstsInput -Name "UseMaintenancePage" -AsBool
    $timeout = Get-VstsInput -Name "Timeout" -AsInt -Require -ErrorAction "Stop"
    $includeBlob = Get-VstsInput -Name "IncludeBlob" -AsBool
    $includeDb = Get-VstsInput -Name "IncludeDb" -AsBool


    # 30 min timeout
    ####################################################################################

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    Write-Host "Inputs:"
    Write-Host "ClientKey: $clientKey"
    Write-Host "ClientSecret: **** (it is a secret...)"
    Write-Host "ProjectId: $projectId"
    Write-Host "SourceEnvironment: $sourceEnvironment"
    Write-Host "TargetEnvironment: $targetEnvironment"
    Write-Host "SourceApp: $sourceApp"
    Write-Host "UseMaintenancePage: $useMaintenancePage"
    Write-Host "Timeout: $timeout"
    Write-Host "IncludeBlob: $includeBlob"
    Write-Host "IncludeDb: $includeDb"

    . "$PSScriptRoot\Helper.ps1"
    WriteInfo

    if ((Test-IsGuid -ObjectGuid $projectId) -ne $true){
        Write-Error "The provided ProjectId is not a guid value."
    }

    if (-not ($env:PSModulePath.Contains("$PSScriptRoot\ps_modules"))){
        $env:PSModulePath = "$PSScriptRoot\ps_modules;" + $env:PSModulePath   
    }

    if (-not (Get-Module -Name EpiCloud -ListAvailable)) {
        Write-Host "Could not find EpiCloud. Installing it."
        Install-Module EpiCloud -Scope CurrentUser -Force
    } else {
        Write-Host "EpiCloud installed."
    }

    Connect-EpiCloud -ClientKey $clientKey -ClientSecret $clientSecret

    $sourceApps = $sourceApp.Split(",")

    $startEpiDeploymentSplat = @{
        ProjectId          = $projectId
        SourceEnvironment  = $sourceEnvironment
        TargetEnvironment  = $targetEnvironment
        SourceApp          = $sourceApps
        UseMaintenancePage = $useMaintenancePage
        IncludeBlob = $includeBlob
        IncludeDb = $includeDb
    }

    $deploy = Start-EpiDeployment @startEpiDeploymentSplat
    $deploy

    $deploymentId = $deploy.id

    if ($deploy.status -eq "InProgress") {
        $deployDateTime = GetDateTimeStamp
        Write-Host "Deploy $deploymentId started $deployDateTime."
        $percentComplete = $deploy.percentComplete
        $status = Progress -projectid $projectId -deploymentId $deploymentId -percentComplete $percentComplete -expectedStatus "AwaitingVerification" -timeout $timeout

        $deployDateTime = GetDateTimeStamp
        Write-Host "Deploy $deploymentId ended $deployDateTime"

        if ($status.status -eq "AwaitingVerification") {
            Write-Host "Deployment $deploymentId has been successful."
        }
        else {
            Write-Warning "The deploy has not been successful or the script has timedout. CurrentStatus: $($status.status)"
            Write-Host "##vso[task.logissue type=error]The deploy has not been successful or the script has timedout. CurrentStatus: $($status.status)"
            Write-Error "The deploy has not been successful or the script has timedout. CurrentStatus: $($status.status)" -ErrorAction Stop
            exit 1
        }
    }
    else {
        Write-Warning "Status is not in InProgress (Current:$($deploy.status)). You can not deploy at this moment."
        Write-Host "##vso[task.logissue type=error]Status is not in InProgress (Current:$($deploy.status)). You can not deploy at this moment."
        Write-Error "Status is not in InProgress (Current:$($deploy.status)). You can not deploy at this moment." -ErrorAction Stop
        exit 1
    }
    Write-Host "Setvariable DeploymentId: $deploy.id"
    Write-Host "##vso[task.setvariable variable=DeploymentId;]$($deploymentId)"

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


param (
    [Parameter(Mandatory=$true)]
        [string] $accessKey,
    [Parameter(Mandatory=$true)]
        [string] $ownerName,
    [Parameter(Mandatory=$true)]
        [string] $appName
)
[string] $apiUri    = "https://api.appcenter.ms/v0.1/apps"
[string] $completed = "completed"
$headers = @{
    "X-API-Token" = $accessKey
}

# main
## Get branches and shas
[string] $branchesApiUri = "$($apiUri)/$($ownerName)/$($appName)/branches"
[string] $branchesStr = (Invoke-WebRequest -Uri $branchesApiUri -UseBasicParsing -Headers $headers).Content
$branches = $branchesStr | ConvertFrom-Json
[array] $branchesWithSha = @();
foreach ($item in $branches) {
    $outputItem = New-Object System.Object
    $outputItem | Add-Member NoteProperty -Name "name" -Value $item.branch.name
    $outputItem | Add-Member NoteProperty -Name "sha" -Value $item.branch.commit.sha
    $branchesWithSha += $outputItem
}

## Commit build for all branches and shas
[array] $jobsDetails = @();
foreach ($branch in $branchesWithSha) {
    Write-Output "Building ""$($branch.name)"" branch..."
    [string] $buildBrachApiUrl = "$($apiUri)/$($ownerName)/$($appName)/branches/$($branch.name)/builds"
    $Body = @{
        sourceVersion = "$($branch.sha)"
        debug = $true
    }
    [string] $buildOutputStr = (Invoke-WebRequest -Method Post -Uri $buildBrachApiUrl -UseBasicParsing -Headers $headers -Body ($Body|ConvertTo-Json) -ContentType "application/json").Content
    $buildOutputJson = $buildOutputStr | ConvertFrom-Json
    $outputItem = New-Object System.Object
    $outputItem | Add-Member NoteProperty -Name "id"         -Value $buildOutputJson.id
    $outputItem | Add-Member NoteProperty -Name "branch"     -Value $buildOutputJson.sourceBranch
    $outputItem | Add-Member NoteProperty -Name "status"     -Value "fake"
    $outputItem | Add-Member NoteProperty -Name "result"     -Value "fake"
    $outputItem | Add-Member NoteProperty -Name "startTime"  -Value $null
    $outputItem | Add-Member NoteProperty -Name "finishTime" -Value $null
    $outputItem | Add-Member NoteProperty -Name "duration"   -Value $null
    $outputItem | Add-Member NoteProperty -Name "logsUri"    -Value $null
    $jobsDetails += $outputItem
}

## Grabbing jobs details
[bool] $allJobsInProcess = $true
Write-Output "Waiting jobs completed..."
while ($allJobsInProcess) {
    for ($i=0;$i -lt $jobsDetails.Count;$i++) {
        [string] $jobStatusUri = "$($apiUri)/$($ownerName)/$($appName)/builds/$($jobsDetails[$i].id)"
        [string] $jobStatusStr = (Invoke-WebRequest -Uri $jobStatusUri -UseBasicParsing -Headers $headers).Content
        $jobStatusJson = $jobStatusStr | ConvertFrom-Json
        if ($jobStatusJson.status -eq $completed) {
            $jobsDetails[$i].status     = $completed
            $jobsDetails[$i].startTime  = $jobStatusJson.startTime
            $jobsDetails[$i].finishTime = $jobStatusJson.finishTime
            $jobsDetails[$i].result     = $jobStatusJson.result
        }
    }
    if ($jobsDetails.status -notcontains "fake") {
        $allJobsInProcess = $false
    }
    Start-Sleep -Seconds 5
}

## collecting output
for ($i=0;$i -lt $jobsDetails.Count;$i++) {
    ### logs uri
    [string] $logsDownloadUri = "$($apiUri)/$($ownerName)/$($appName)/builds/$($jobsDetails[$i].id)/downloads/logs"
    [string] $logsDownloadStr = (Invoke-WebRequest -Uri $logsDownloadUri -UseBasicParsing -Headers $headers).Content
    $jobsDetails[$i].logsUri = ($logsDownloadStr | ConvertFrom-Json).uri
    
    ### duration
    $dur = $(Get-Date $jobsDetails[$i].finishTime) - $(Get-Date $jobsDetails[$i].startTime)
    $durOut = "{0:c}" -f $dur
    $jobsDetails[$i].duration = $durOut.Split(".")[0]
}

Write-Output "Jobs details:"
$jobsDetails
##################################################
# HelloID-Conn-Prov-Source-SDWorx-X-Tend365-Persons
#
# Version: 1.1.0
##################################################

# Initialize default values
$config = $configuration | ConvertFrom-Json

function Resolve-XTendError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        try {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails
            $httpErrorObj.FriendlyMessage = ($httpErrorObj.ErrorDetails | ConvertFrom-Json).error_description
        }
        catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}

try {
    $tokenBody = @{
        'grant_type'    = 'client_credentials'
        'client_id'     = $config.ClientId
        'client_secret' = $config.ClientSecret
        'resource'      = $config.BaseUrl
    }

    $splatGetToken = @{
        Uri    = "https://login.microsoftonline.com/$($config.TenantId)/oauth2/token"
        Method = 'POST'
        Body   = $tokenBody
    }

    $accessToken = (Invoke-RestMethod @splatGetToken).access_token
    $headers = @{
        Authorization = "Bearer $($accessToken)"
        Accept        = 'application/json; charset=utf-8'
    }
    $splatGetUsers = @{
        Uri     = "$($config.BaseUrl)/data/HelloIdDatas" #?`$filter=(StartDate le $($startDate) and EndDate ge $($endDate))"
        Headers = $headers
        Method  = 'GET'
    }

    $persons = ((Invoke-WebRequest @splatGetUsers).content | ConvertFrom-Json).value
    $groupedPersons = $persons | Group-Object -Property PersonnelNumber

    Write-Information "Retrieved $($groupedPersons.count) persons from the source system."

    $today = (Get-Date).Date
    $futureCutoffDate = $today.AddDays([int]$config.FutureDays).Date
    $pastCutoffDate = $today.AddDays( - [int]$config.HistoricalDays).Date

    $filteredGroups = foreach ($personGroup in $groupedPersons) {
        $contracts = $personGroup.Group
        $includePerson = $false

        foreach ($contract in $contracts) {
            $startDate = ([datetime]$contract.StartDate).Date
            $hasEndDate = ($null -ne $contract.EndDate -and -not [string]::IsNullOrWhiteSpace("$($contract.EndDate)"))
            $endDate = if ($hasEndDate) { ([datetime]$contract.EndDate).Date } else { [datetime]::MaxValue.Date }

            # Active
            if (($startDate -le $today) -and ($endDate -ge $today)) {
                $includePerson = $true
                break
            }

            # Inactive (Pre)
            if ((-not (($startDate -le $today) -and ($endDate -ge $today))) -and
                ($startDate -gt $today) -and
                ($startDate -le $futureCutoffDate)) {
                $includePerson = $true
                break
            }

            # Inactive (Post)
            if ($hasEndDate -and
                ($endDate -lt $today) -and
                ($endDate -ge $pastCutoffDate)) {
                $includePerson = $true
                break
            }
        }

        if ($includePerson) { $personGroup }
    }

    Write-Information "After filter: $($filteredGroups.Count) persons (active / pre[$($config.FutureDays)] / post[$($config.HistoricalDays)])."

    foreach ($person in $filteredGroups) {
        # Selects the most relevant person, prioritizing the employment with the latest enddate.
        $selectedPerson = $person.group | Sort-Object @{Expression = { if ($_.EndDate -eq $null) { [datetime]::MaxValue } else { $_.EndDate } } } -Descending | Select-Object -First 1

        $helloIdPerson = $selectedPerson.psobject.Copy()
        $helloIdPerson | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
        $helloIdPerson | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
        $helloIdPerson | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force

        $helloIdPerson.ExternalId = $helloIdPerson.PersonnelNumber
        $helloIdPerson.DisplayName = "$($helloIdPerson.PersonnelNumber) ($($helloIdPerson.FirstName) $($helloIdPerson.LastNamePrefix) $($helloIdPerson.BirthName))" 
        $helloIdPerson.Contracts = $person.group
        Write-Output $helloIdPerson | ConvertTo-Json -Depth 10
    }
}
catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-XTendError -ErrorObject $ex
        Write-Verbose "Could not import X-Tend persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.FriendlyMessage)"
        Write-Error "Could not import X-Tend persons. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        Write-Verbose "Could not import X-Tend persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import X-Tend persons. Error: $($ex.Exception.Message)"
    }
}
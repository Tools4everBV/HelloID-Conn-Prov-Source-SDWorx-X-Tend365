##################################################
# HelloID-Conn-Prov-Source-XTrend-Persons
#
# Version: 1.0.0
##################################################
# Initialize default value's
$config = $configuration | ConvertFrom-Json

function Resolve-XTrendError {
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
        } catch {
            $httpErrorObj.FriendlyMessage = "Received an unexpected response. The JSON could not be converted, error: [$($_.Exception.Message)]. Original error from web service: [$($ErrorObject.Exception.Message)]"
        }
        Write-Output $httpErrorObj
    }
}

try {
    $tokenBody = @{
        'grant_type'    = 'client_credentials'
        'client_id'     = $config.clientId
        'client_secret' = $config.clientSecret
        'resource'      = $config.BaseUrl
    }
    $splatGetToken = @{
        Uri    = "https://login.microsoftonline.com/$($config.TenantId)/oauth2/token"
        Method = 'POST'
        Body   = $tokenBody
    }
    $accessToken = (Invoke-RestMethod @splatGetToken).access_token

    $startDate = (Get-Date).AddDays(-$config.HistoricalDays).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
    $endDate = (Get-Date).AddDays($config.FutureDays).ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'")
    $headers = @{
        Authorization = "Bearer $($accessToken)"
        Accept        = 'application/json; charset=utf-8'
    }
    $splatGetUsers = @{
        Uri     = "$($config.BaseUrl)/data/HelloIdDatas?`$filter=(StartDate le $($startDate) and EndDate ge $($endDate))"
        Headers = $headers
        Method  = 'GET'
    }
    $persons = ((Invoke-WebRequest @splatGetUsers).content | ConvertFrom-Json).value
    $groupedPersons = $persons | Group-Object -Property PersonnelNumber

    Write-Verbose "Retrieved $($groupedPersons.count) persons from the source system."
    foreach ($person in $groupedPersons) {
        try {
            $contracts = [System.Collections.Generic.List[object]]::new()
            foreach ($personEntry in $person.Group) {
                $ShiftContract = @{
                    externalId               = "$($personEntry.dataAreaId)$($personEntry.PersonnelNumber)$($personEntry.StartDate)"
                    JobId                    = $personEntry.JobId
                    JobDescription           = $personEntry.JobDescription
                    Location                 = $personEntry.Location
                    LocationCode             = $personEntry.LocationCode
                    WorkplaceTypeId          = $personEntry.WorkplaceTypeId
                    WorkplaceTypeDescription = $personEntry.WorkplaceTypeDescription
                    DepartmentNumber         = $personEntry.DepartmentNumber
                    DepartmentDescription    = $personEntry.DepartmentDescription
                    CompanyNumber            = $personEntry.CompanyNumber
                    HoursPerWeek             = $personEntry.HoursPerWeek
                    CostCenter               = $personEntry.CostCenter
                    Manager                  = $personEntry.Manager
                    startAt                  = $personEntry.StartDate
                    endAt                    = $personEntry.EndDate
                }
                $contracts.Add($ShiftContract)
            }

            # Selects the most relevant person, prioritizing the longest active employment.
            $selectedPerson = $person.group | Select-Object -First 1
            if ($person.count -gt 1) {
                $today = (Get-Date).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
                $activePersons = $person.group | Where-Object { $_.StartDate -le $today -and ($_.EndDate -ge $today -or $_.EndDate -eq $null) }
                $selectedPerson = $activePersons | Sort-Object @{Expression = { if ($_.EndDate -eq $null) { [datetime]::MaxValue } else { $_.EndDate } } } -Descending | Select-Object -First 1
            }

            if ($contracts.Count -gt 0) {
                $personObj = [PSCustomObject]@{
                    ExternalId            = $selectedPerson.PersonnelNumber
                    DisplayName           = $selectedPerson.PersonnelNumber
                    Initials              = $selectedPerson.Initials
                    FirstName             = $selectedPerson.FirstName
                    LastNamePrefix        = $selectedPerson.LastNamePrefix
                    BirthName             = $selectedPerson.BirthName
                    KnownAs               = $selectedPerson.KnownAs
                    PartnerLastNamePrefix = $selectedPerson.PartnerLastNamePrefix
                    PartnerLastName       = $selectedPerson.PartnerLastName
                    BirthDate             = $selectedPerson.BirthDate
                    PrivateEmail          = $selectedPerson.PrivateEmail
                    ProfessionalEmail     = $selectedPerson.ProfessionalEmail
                    WorkPhoneNumber       = $selectedPerson.WorkPhoneNumber
                    WorkMobileNumber      = $selectedPerson.WorkMobileNumber
                    Contracts             = $contracts
                }
                Write-Output $personObj | ConvertTo-Json -Depth 20
            }
        } catch {
            $ex = $PSItem
            if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                $errorObj = Resolve-XTrendError -ErrorObject $ex
                Write-Verbose "Could not import X-Trend person [$($person.uname)]. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
                Write-Error "Could not import X-Trend person [$($person.uname)]. Error: $($errorObj.FriendlyMessage)"
            } else {
                Write-Verbose "Could not import X-Trend person [$($person.uname)]. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
                Write-Error "Could not import X-Trend person [$($person.uname)]. Error: $($errorObj.FriendlyMessage)"
            }
        }
    }
} catch {
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-XTrendError -ErrorObject $ex
        Write-Verbose "Could not import X-Trend persons. Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.FriendlyMessage)"
        Write-Error "Could not import X-Trend persons. Error: $($errorObj.FriendlyMessage)"
    } else {
        Write-Verbose "Could not import X-Trend persons. Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
        Write-Error "Could not import X-Trend persons. Error: $($errorObj.FriendlyMessage)"
    }
}
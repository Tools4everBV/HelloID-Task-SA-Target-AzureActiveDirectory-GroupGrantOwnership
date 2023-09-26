# HelloID-Task-SA-Target-AzureActiveDirectory-GroupGrantOwnership
##################################################################
# Form mapping
$formObject = @{
    GroupIdentity = $form.GroupIdentity
    ownersToAdd   = $form.ownersToAdd
}
try {
    Write-Information "Executing AzureActiveDirectory action: [GroupGrantOwnership] for: [$($formObject.GroupIdentity)]"
    Write-Information "Retrieving Microsoft Graph AccessToken for tenant: [$AADTenantID]"
    $splatTokenParams = @{
        Uri         = "https://login.microsoftonline.com/$($AADTenantID)/oauth2/token"
        ContentType = 'application/x-www-form-urlencoded'
        Method      = 'POST'
        Body        = @{
            grant_type    = 'client_credentials'
            client_id     = $AADAppID
            client_secret = $AADAppSecret
            resource      = 'https://graph.microsoft.com'
        }
    }
    $accessToken = (Invoke-RestMethod @splatTokenParams).access_token

    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add("Authorization", "Bearer $($accessToken)")
    $headers.Add("Content-Type", "application/json")

    foreach ($owner in $formObject.ownersToAdd) {
        try {
            $splatAddOwnerToGroup = @{
                Uri         = "https://graph.microsoft.com/v1.0/groups/$($formObject.GroupIdentity)/owners/`$ref"
                ContentType = 'application/json'
                Method      = 'POST'
                Headers     = $headers
                Body        = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($owner.UserIdentity)" } | ConvertTo-Json -Depth 10
            }
            $null = Invoke-RestMethod @splatAddOwnerToGroup

            $auditLog = @{
                Action            = 'UpdateResource'
                System            = 'AzureActiveDirectory'
                TargetIdentifier  = $formObject.GroupIdentity
                TargetDisplayName = $formObject.GroupIdentity
                Message           = "AzureActiveDirectory action: [GroupGrantOwnership] for group [$($formObject.GroupIdentity)] for: [$($owner.UserIdentity)] executed successfully"
                IsError           = $false
            }

            Write-Information -Tags 'Audit' -MessageData $auditLog
            Write-Information $auditLog.Message
        } catch {
            $ex = $_
            if (-not[string]::IsNullOrEmpty($ex.ErrorDetails)) {
                $errorExceptionDetails = ($_.ErrorDetails | ConvertFrom-Json).error.Message
            } else {
                $errorExceptionDetails = $ex.Exception.Message
            }

            if (($ex.Exception.Response) -and ($Ex.Exception.Response.StatusCode -eq 404)) {
                # 404 indicates already removed
                $auditLog = @{
                    Action            = 'UpdateResource'
                    System            = 'AzureActiveDirectory'
                    TargetIdentifier  = $formObject.GroupIdentity
                    TargetDisplayName = $formObject.GroupIdentity
                    Message           = "AzureActiveDirectory action: [GroupGrantOwnership for group [$($formObject.GroupIdentity))] ] for: [$($owner.UserIdentity)] executed successfully. Note that the account was not a member"
                    IsError           = $false
                }
                Write-Information -Tags 'Audit' -MessageData $auditLog
                Write-Information $auditLog.Message
            } else {
                $auditLog = @{
                    Action            = 'UpdateResource'
                    System            = 'AzureActiveDirectory'
                    TargetIdentifier  = $formObject.GroupIdentity
                    TargetDisplayName = $formObject.GroupIdentity
                    Message           = "Could not execute AzureActiveDirectory action: [GroupGrantOwnership] for group [$($formObject.GroupIdentity)] for: [$($owner.UserIdentity)], error: $($errorExceptionDetails)"
                    IsError           = $true
                }
                Write-Information -Tags 'Audit' -MessageData $auditLog
                Write-Error $auditLog.Message
            }
        }
    }
} catch {
    $ex = $_
    if (-not[string]::IsNullOrEmpty($ex.ErrorDetails)) {
        $errorExceptionDetails = ($_.ErrorDetails | ConvertFrom-Json).error.Message
    } else {
        $errorExceptionDetails = $ex.Exception.Message
    }

    $auditLog = @{
        Action            = 'UpdateResource'
        System            = 'AzureActiveDirectory'
        TargetIdentifier  = $formObject.GroupIdentity
        TargetDisplayName = $formObject.GroupIdentity
        Message           = "Could not execute AzureActiveDirectory action: [GroupGrantOwnership] for: [$($formObject.GroupIdentity)], error: $($errorExceptionDetails)"
        IsError           = $true
    }

    Write-Information -Tags 'Audit' -MessageData $auditLog
    Write-Error "$($auditLog.Message)"
}
##################################################################
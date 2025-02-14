#What group are we grabbing machines from?
$SourceGroupName = "ServerTest"

#base constants, api user in AMP, base uri (incase it ever changes...)
$baseuri = "https://api.amp.cisco.com/"

#v1 credentials from https://console.amp.cisco.com/api_credentials
$clientid = "yourclienid"
$apikey = "yourapiid"
#convert the login info to the form needed by the api "clientid:apikey", then base64 encoded
$EncodedUsernamePassword = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($('{0}:{1}' -f $clientid, $apikey)))

#v3 credentials from https://xdr.us.security.cisco.com/administration/api-clients or ??
$v3clientid = "xdr/secureclientmgmt id"
$v3apikey = "xdr/secureclientmgmt apikey"
#convert the login info to the form needed by the api "clientid:apikey", then base64 encoded
$v3EncodedUsernamePassword = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($('{0}:{1}' -f $v3clientid, $v3apikey)))


$Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$Headers.Add("Content-Type", "application/x-www-form-urlencoded")
$Headers.Add("Authorization", "Basic $($v3EncodedUsernamePassword)")
$Headers.Add("Accept-Encoding", "gzip, deflate") 

#get the token from XDR/Secure Cloud for v3 calls
$body = "grant_type=client_credentials"
$url = 'https://visibility.amp.cisco.com/iroh/oauth2/token'

Try {
	$TokenResponse = Invoke-RestMethod -uri $url -Method 'POST' -Headers $Headers -body $body
    } 
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to the get the bearer token from XDR.`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($TokenResponse.metadata.results.total -eq 0) {

	Write-host "Error: Got no token??"
	exit
	}
$bearerToken=$TokenResponse.access_token
$Headers.Remove("Authorization")
$Headers.Add("Authorization", "Bearer $($bearerToken)")

#use the Secure Cloud token to get CSE v3 api token.
$url = $baseuri + "v3/access_tokens"
Try {
	$TokenResponse = Invoke-RestMethod -uri $url -Method 'POST' -Headers $Headers -body $body
    } 
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to the get the bearer token from SecureEndpoint.`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($TokenResponse.metadata.results.total -eq 0) {

	Write-host "Error: Got no token??"
	exit
	}
$CSEbearerToken=$TokenResponse.access_token

#doing a v1 call, put the v1 basic auth back in the headers
$Headers.Remove("Authorization")
$Headers.Add("Authorization", "Basic $($EncodedUsernamePassword)")

#get all the groups, keep that in GroupResponse
$filter ="v1/groups"
$url = $baseuri + $filter
$body = ""

Try {
	$GroupResponse = Invoke-RestMethod -uri $url -Method 'GET' -Headers $Headers
    } 
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to the get the groups.`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($GroupResponse.metadata.results.total -eq 0) {
	#api came back but no groups??  
	Write-host "Error: Got no groups??"
	exit
	}
#Get the guid of the group that you have at the top
$sourcegroupguid = $GroupResponse.data | where { $_.name -eq $SourceGroupName } | Select -ExpandProperty Guid

$filter ="/v1/computers?group_guid="+$sourcegroupguid
$url = $baseuri + $filter

#Get the list of computers in the group
Try {
	$Computersresponse = Invoke-RestMethod -uri $url -Method 'GET' -Headers $Headers
    } 
Catch 
    {    
    $RestError = $_.Exception
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    exit
    }

if ($Computersresponse.metadata.results.total -eq 0){
	write-host "No machines to uninstall? no machines in group? `n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url)"
	exit
	}


#doing a v3 call, put the V3 back in the headers
$Headers.Remove("Authorization")
$Headers.Add("Authorization", "Bearer $($CSEbearerToken)")


#For this call, need org id, and machine ids (from v1 call)
##### makes assumption that there is only one organization you have access to!!!!!!
$filter= "v3/organizations?size=1"
$url=$baseuri + $filter
Try {
	$OrganizationResponse = Invoke-RestMethod -uri $url -Method 'GET' -Headers $Headers
    } 
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to the get the Organizations.`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($OrganizationResponse.metadata.results.total -eq 0) {
	#api came back but no organization??  
	Write-host "Error: Got no organization??"
	exit
	}

$orgid = $OrganizationResponse.data[0].organizationIdentifier


for ($i=0;$i -lt $Computersresponse.metadata.results.total;$i++) {
	$machine = $Computersresponse.data[$i].connector_guid
	$filter="v3/organizations/$orgid/computers/$machine/uninstall_request"
	$url = $baseuri + $filter
			
	try {
		$response=Invoke-RestMethod -Method PUT -Uri $url -Headers $Headers 
		}
	catch 
		{    
		$RestError = $_.Exception
		$HttpStatusCode = $RestError.Response.StatusCode.value__
		$HttpStatusDescription = $RestError.Response.StatusDescription
		write-host "Call to to uninstall failed.`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
		}
	write-host "$machine uninstall sent"
}

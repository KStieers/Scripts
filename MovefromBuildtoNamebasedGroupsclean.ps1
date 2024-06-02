#What group are we grabbing machines from?
$SourceGroupName = "Sourcegroup"

#How many letters at the beginning match?
$lettercount=3 

#base constants, SCCM api user in AMP, base uri (incase it ever changes...)
$baseuri = "https://api.amp.cisco.com/v1/"
$clientid = "putyourclientidhere"
$apikey = "putyourapikey"

#convert the login info to the form needed by the api "clientid:apikey", then base64 encoded
$EncodedUsernamePassword = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($('{0}:{1}' -f $clientid, $apikey)))

#build headers
$Headers = @{'Authorization' = "Basic $($EncodedUsernamePassword)"; 'accept' = 'application/json'; 'Content-type' = 'application/json'; 'Accept-Encoding' = 'gzip, deflate'}

#get all the groups, keep that in GroupResponse
$filter ="groups"
$url = $baseuri + $filter

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
#Get the guid of the group
$sourcegroupguid = $GroupResponse.data | where { $_.name -eq $SourceGroupName } | Select -ExpandProperty Guid

$filter ="computers?group_guid="+$sourcegroupguid
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
	write-host "No machines to move"
	exit
	}

for ($i=0;$i -lt $Computersresponse.metadata.results.total;$i++) {
	$machine = $Computersresponse.data[$i].hostname
	$matchstring = $machine.substring(0,$lettercount) + "*"
	$url=$Computersresponse.data[$i].links.computer
	
	$groupguid = $GroupResponse.data | where { $_.name -like $matchstring } | Select -ExpandProperty Guid
	
	$body = "{`"group_guid`":`"$groupguid`"}"
	
	try {
		$response=Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $body 
		}
	catch 
		{    
		$RestError = $_.Exception
		$HttpStatusCode = $RestError.Response.StatusCode.value__
		$HttpStatusDescription = $RestError.Response.StatusDescription
		write-host "Moving $machine failed."
		}
	write-host "$machine moved"
}
	

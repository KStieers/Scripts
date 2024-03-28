#get new version from commandline
param (
   [Parameter(Mandatory=$true)][string]$newversion,
   [string]$product,
   [string]$name  
 )

#parse newversion
$major,$minor,$build,$revision =  $newversion.split('.')

#set start date to today, end to 2 months from now
$start = get-date -format "yyyy-MM-dd HH:mm:ss"
$end = (get-date).addmonths(2)
$end = (Get-date -date $end -format ("yyyy-MM-dd HH:mm:ss"))


#base constants, api user in AMP, base uri (incase it ever changes...)
$baseuri = "https://api.amp.cisco.com/v1/"
$clientid = "clientid from amp"
$apikey = "api key from amp"

#convert the login info to the form needed by the api "clientid:apikey", then base64 encoded
$EncodedUsernamePassword = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($('{0}:{1}' -f $clientid, $apikey)))

#build headers
$Headers = @{'Authorization' = "Basic $($EncodedUsernamePassword)"; 'accept' = 'application/json'; 'Content-type' = 'application/json'; 'Accept-Encoding' = 'gzip, deflate'}

#*************************************************************************************
#Build the url
$filter ="policies"
if ($product -eq "windows" -or $product -eq "linux" -or $product -eq "mac") {
	$filter=$filter+"?product="+$product
}

if ($name.length -gt 0){
	if ($filter.contains("product")){
		$filter=$filter+"&name="+$name
	}
	else{
	$filter = $filter+"?name="+$name
	}	
}

$url = $baseuri + $filter


#get all of the policies
Try {
	$policyset = Invoke-RestMethod -uri $url -Method 'GET' -Headers $Headers
    } 
Catch 
    {    
    $RestError = $_.Exception
    $HttpStatusCode = $RestError.Response.StatusCode.value__
	$HttpStatusDescription = $RestError.Response.StatusDescription
	$HttpDetails = $RestError.Response.StatusDescription.Details
	write-host Getting policyset failed - Error: $HTTPStatusCode $HttpStatusDescription $HttpDetails
    exit
    }

$numpolicies = $policyset.metadata.results.total

#check the number of policies returned... 
switch ($numpolicies)
{
	0 
	{
	write-host "Got no polices back"
	exit 
	}  #zero 
	
	default
	{
    
	#build powershell hash table becasue its easier than fiddling with string manipulation, then convert to json
	$body =	ConvertTo-Json @{
		version=@{
			major=$major;
			minor=$minor;
			build=$build;
			revision=$revision};
		date_range=@{
			start=$start;
			end =$end};
		update_interval = 3600
		}     #body build
	
 
	for ($i=0;$i -lt $numpolicies;$i++) {

		$url = $policyset.data[$i].links.policy+"/connector_upgrade"
		write-host Setting Policy: $policyset.data[$i].name
		try {$response=Invoke-RestMethod -Method PUT -Uri $url -Headers $Headers -Body $body }
		catch {   
			$RestError = $_.Exception
			$HttpStatusCode = $RestError.Response.StatusCode.value__
			$HttpStatusDescription = $RestError.Response.StatusDescription
			$HttpDetails = $RestError.Response.StatusDescription.Details
			write-host Setting policy failed: $response.data[$i].name.  Error: $HTTPStatusCode $HttpStatusDescription $HttpDetails
		}  #catch
	}  #for

		
	} #default
	
} #switch
  
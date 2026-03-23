
#base constants, base uri (incase it ever changes...)
$baseuri = "https://dhxxxx-esa1.iphmx.com/esa/api/v2.0/"  
$clientid = "username"		#username
$apikey = "password"		#password


#name of dictionary in ESA 
$dictionary = "Names"

#convert the login info to the form needed by the api "clientid:apikey", then base64 encoded
$EncodedUsernamePassword = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($('{0}:{1}' -f $clientid, $apikey)))

#build headers
$Headers = @{'Authorization' = "Basic $($EncodedUsernamePassword)"; 'accept' = '*/*'; 'Content-type' = 'application/json'; 'Accept-Encoding' = 'gzip, deflate'}

write-host "Calling SQL..."
$ds=Invoke-Sqlcmd -ServerInstance "sql7" -TrustServerCertificate -as Dataset -Query "SELECT [FirstName]+' '+Replace(Replace([LastName],'-',' '),'''',' ') as name
  FROM [employeedatabase].[dbo].[employeetable]
  where isactive = 1 and firstname not like '%test%' and lastname not like '%test%' and companyid in (38,41,42,43) and
  (Position like '%President%' or
position like '%accountant%' or
position like '%accounting%' or
position like '%officer%' or 
Position like '%Director%' or
position like '%Accounts%' or 
position like '%Controller%' or
position like '%Chariman%' or DepartmentID in (3,6,7))
Union 
select 'Jobs' as name
Union
select 'Careers' as name
Union
Select 'Human Resources' as name

order by name"

$list=$DS.Tables[0] | select $DS.Tables[0].Columns[0].Rows
[string[]]$onetlist =@()
$onetlist = $list.name    # .name is the name of the column from the SQL query above. 

Write-host "Getting names from ESA..."
#get all the Names from the dictionary
$filter ="config/dictionaries/"+$dictionary+"?device_type=esa&mode=cluster"
$url = $baseuri + $filter

Try {
	$response = Invoke-RestMethod -uri $url -Method 'GET' -Headers $Headers
	}
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
	$ErrMsg = $RestError.Message
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to get the list of names.`n"
	Write-host "$($ErrMsg)`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($response.metadata.results.total -eq 0) {
	#api came back but no names??  
	Write-host "Error: API succeeded, but got no names??"
	exit
	}

[string[]]$esalist = @()
$esalist = $response.data.words

for ( $index = 0; $index -lt $esalist.count; $index++ )
{  
    $esalist[$index] = $($esalist[$index]).Replace(' 1','')
}

Write-host "Building lists..."
[string[]]$removefromESA = $esalist | Where {$onetlist -notcontains $_}
[string[]]$AddtoESA = $onetlist | Where {$esalist -notcontains $_}


if ($addtoESA.count -ge 1) {
Write-host "Adding these to the ESAs:`n" 
Write-host ($addtoESA -join "`n")

$body = "{`"data`": {`"words`": ["  
$addtoESA.foreach({$body=$body + "[""" + $_ + """] ,"})
$body = $body.Substring(0, $body.Length - 1)
$body = $body + '] } } '

$filter ="config/dictionaries/"+$dictionary+"/words?device_type=esa&mode=cluster"
$url = $baseuri + $filter

Try {
	$response = Invoke-RestMethod -uri $url -Method 'POST' -Headers $Headers -body $body
	}
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
	$ErrMsg = $RestError.Message
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to add the list of names.`n"
	Write-host "$($ErrMsg)`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($response.metadata.results.total -eq 0) {
	#api came back but no names??  
	Write-host "Error: API succeeded, but got no names??"
	exit
	}
}


if ($removefromESA.count -ge 1) {

write-host "Removing these from the ESAs:`n" 
Write-host ($removefromESA -join "`n")

$body = "{`"data`": {`"words`": ["  

$removefromesa.foreach({$body=$body + """" + $_ + """ ,"})
$body = $body.Substring(0, $body.Length - 1)
$body = $body + '] } } '

#get all the Names from the dictionary
$filter ="config/dictionaries/"+$dictionary+"/words?device_type=esa&mode=cluster"
$url = $baseuri + $filter

Try {
	$response = Invoke-RestMethod -uri $url -Method 'DELETE' -Headers $Headers -body $body
	}
Catch 
    {   
	#if the api fails for whatever reason
    $RestError = $_.Exception
	$ErrMsg = $RestError.Message
    $HttpStatusCode = $RestError.Response.StatusCode.value__
    $HttpStatusDescription = $RestError.Response.StatusDescription
    write-host "Unable to delete the list of names.`n"
	Write-host "$($ErrMsg)`n Status Code: $($HttpStatusCode) - Http Status Description: $($HttpStatusDescription)`n $url"
	exit
    }
if ($response.metadata.results.total -eq 0) {
	#api came back but no names??  
	Write-host "Error: API succeeded, but got no names??"
	exit
	}
}


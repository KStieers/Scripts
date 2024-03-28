this script updates the policies in Cisco Secure Endpoint in bulk
/updatepoliciesclean.ps1  version <-product=windows|linux|mac> <-name=string to match policy name>

version = the new version number.  ex. 8.2.4.30130
product is what product policies to update.  
name is a filter on the policy names ex. "Test" for all of your test policies. 

UpdatePoliciesClean - this script updates the policies in Cisco Secure Endpoint in bulk
/updatepoliciesclean.ps1  version <-product=windows|linux|mac> <-name=string to match policy name>

        version = the new version number.  ex. 8.2.4.30130
        product is what product policies to update.  
        name is a filter on the policy names ex. "Test" for all of your test policies. 
        (need to edit the script to add your keys)


MovefromBuildtoNamebasedGroupsclean.ps1 - this script looks in a group and moves machines to a group whose name matches the begining of the machine name 
    (think machines names MSPxxx, DENxxx, LAXxxx, SFOxxx moving to groups named MSP, DEN, LAX, SFO)
    adjust the match letter count and source group in the code, add API and key to the script.


GroupUninstallClean.ps1
    grabs all machines in a group and sends the uninstall call
    
    

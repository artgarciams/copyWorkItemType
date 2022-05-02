#
# FileName  : CreateMain.ps1
# Date      : 005/02/2022
# Author    : Arthur A. Garcia
# Purpose   : This script will create a copy of a work item type from a given process
#             It will take the process and work item type to copy from and process and work item type to copy to as inputs


#import modules
$modName = $PSScriptRoot + "\ProjectAndGroup.psm1" 
Import-Module -Name $modName 

# get parameter data for scripts
$UserDataFile = $PSScriptRoot + "\ProjectDef.json"
$userParameters = Get-Content -Path $UserDataFile | ConvertFrom-Json

Write-Output $userParameters.VSTSMasterAcct

#
# INPUTS:
#          userParams - Projectdef.json file with parameters used by the script.
#          InheritedProcessName - The process to copy work item type from
#          DestinationProcess   - Name of the process to copy the new work item type to
#          NewWorkItemName      - Name of the work item type to copy from
#          WorkItemToCopy       - Name of work item type to copy to
#
Copy-ProcessAndWorkItemType -userParams $userParameters -InheritedProcessName "Opportunity Tracking - Master" -DestinationProcess "Opportunity Tracking - Master" -NewWorkItemName "Test Opportunity" -WorkItemToCopy "Government opportunity"

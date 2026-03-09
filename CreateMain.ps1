#
# FileName  : CreateMain.ps1
# Date      : 005/02/2022
# Author    : Arthur A. Garcia
# Purpose   : This script will create a copy of a work item type from a given process
#             It will take the process and work item type to copy from and process and work item type to copy to as inputs
# Usage     : Change the parameters below the INPUTS section, then run this script '.\CreateMain.ps1'


#import modules
$modName = $PSScriptRoot + "\ProjectAndGroup.psm1" 
Import-Module -Name $modName 

# get parameter data for scripts
$UserDataFile = $PSScriptRoot + "\ProjectDef.json"
$userParameters = Get-Content -Path $UserDataFile | ConvertFrom-Json

Write-Output $userParameters.VSTSMasterAcct

#
# INPUTS:
#          userParams           - Projectdef.json file with parameters used by the script.
#          InheritedProcessName - The process to copy work item type from
#          DestinationProcess   - Name of the process to copy the new work item type to
#          WorkItemCopyFrom     - Name of the work item type to copy from
#          NewWorkItemName      - Name of work item type to copy to
#
Copy-ProcessAndWorkItemType -userParams $userParameters `
                            -InheritedProcessName "Opportunity Tracking - Master" `
                            -DestinationProcess   "Opportunity Tracking - Master" `
                            -WorkItemCopyFrom     "Test Opportunity" `
                            -NewWorkItemName      "Government opportunity"

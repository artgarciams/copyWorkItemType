# copyWorkItemType
Copy a work item type using the Azure DevOps API's. This script will copy an existing work item type from one process into another or the same process.
The point of this script is that there is no way in the current UI to copy a work item type within a process. You can copy the whole process, but not individual work item types. This script allows you to copy just the work item type.



 INPUTS:</br>
          userParams - Projectdef.json file with parameters used by the script.</br>
          InheritedProcessName - The process to copy work item type from</br>
          DestinationProcess   - Name of the process to copy the new work item type to</br>
          NewWorkItemName      - Name of the work item type to copy from</br>
          WorkItemToCopy       - Name of work item type to copy to</br>
</br>
Additional inputs:</br>
    There is a ProjectDef.json file in this project. This file contains the following fields</br>
        "VSTSMasterAcct"  - The Organization name of your DevOps porject</br>
        "userEmail"       - The email of the user</br>
        "PAT"             - Personal Access token in order to have permission to copy.</br>
        "HTTP_preFix"    : "https"</br>

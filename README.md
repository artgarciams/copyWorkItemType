# Copy Work Item Type
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
</br>
So, let’s start with the hierarchy. Everything in ADO has a hierarchy. Processes are derived from the four standard processes: Agile, Scrum, CMMI and Basic. You cannot create a new process, but you can inherit from one of the four to create your process. Once you create the process you will have work item types that come standard with each process. For example, if you inherit from an Agile process your new process will have the following work item types: Epic, Features, User Stories, Bug, Tasks, and Issues. I may have left ones out, but you get the idea. Now the fun starts. So, you create a new work item type to handle your specific business needs, but another team wants to do something similar. Now you must copy each field, each page, etc.   What I will outline is how to do this copy just using the API’s and not having to hand copy each field. We will assume for this discussion that you already have the process and the work item type you want to copy. We also assume the new work item type does not already exist. Modifying an existing work item type to add any missing fields is possible, but I found it much easier to start from scratch. You can easily modify this code to loop through an existing work item, but I choose to do it this way. </br>

</br>

<lu>The steps we will follow are:
 <li>Create new work item type</li>
 <li>Create pages for new work item type by looping through target work item type and adding missing pages</li>
 <li>Create stages for new work item type</li>
 <li>Loop through each page in target work item type</li>
 <dd>-Loop through each section in each page</dd>
 <dd>-Loop thru each group in each section</dd>
 <dd>-Loop through each control in each group</dd>
 <dd>-Add field to new work item type (a control holds only 1 field from what I have seen)</dd>
 <dd>-Add group to given section</dd>
 <dd>-Add control to given group</dd>
</lu>
This is how the code is structured. I thought it may be good to understand the flow before diving into the code. Now that we have that out of the way let’s start with adding the new work item type.
Once the new work item type is created you then need to add the stages from the work item you are copying from.

    # new process work item type does not exist add it
    if([string]::IsNullOrEmpty($newWKItem) )
    {
        # Create work item type within new process
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/create?view=azure-devops-rest-7.1
        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2
        $workitemTypeJson = @{
            color = "f6546a"
            icon = "icon_airplane"
            description = "my first powershell induced workitem type"
            name = $NewWorkItemName
            isDisabled = $false       
        }
        # add work item
        $newWkJson = ConvertTo-Json -InputObject $workitemTypeJson
        $newWkItemsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'    
        $newWKItem = Invoke-RestMethod -Uri $newWkItemsUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newWkJson

        # not get list of all work items including the one we added
        $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
        $newWKItemList = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
        $newWKItem =  $newWKItemList.value | Where-Object {$_.name -eq $NewWorkItemName}

        # get states of work item to copy. this will be used to add states to new work item
        # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/list?view=azure-devops-rest-7.1
        # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states?api-version=7.1-preview.1
        $getAllStatesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $WorkItemType.referenceName + "/states?api-version=7.1-preview.1"
        $getAllStates = Invoke-RestMethod -Uri $getAllStatesUrl -Method Get -Headers $authorization
        Write-Host $getAllStates

        # loop thru states of work item to copy and add to new work item
        foreach ($state in $getAllStates.value) 
        {
            $ddState = @{
                name = $state.name
                color = $state.color
                stateCategory = $state.stateCategory
               # order = $state.order
            }
            $newState = ConvertTo-Json -InputObject $ddState

           # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/states/create?view=azure-devops-rest-7.1
           # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/states?api-version=7.1-preview.1
           $addStateUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/states?api-version=7.1-preview.1"
           $addState = Invoke-RestMethod -Uri $addStateUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newState
           Write-Host $addState 
        }
    }

This will give you the basic Work Item type with the states added from the work item target. Once the work item type is created by default it will have one page and four sections. From Left to right the first three sections reflect the three columns on the page. I have yet to figure out what the fourth section is for, but maybe in the next blog we can visit that. Suffice to say we only need to be concerned with the first three sections. Here is the code to add the pages to the new work item type. By adding the work item types it makes it somewhat easier to add the fields. 
You just look through each page in the layout and add the fields.
    # loop through layout to copy and add pages  to new layout if they don’t exist
    foreach ($Curritem in $WorkItemType.layout.pages) 
    {      
        $pgExists = $newPages | Where-Object {$_.label -eq $Curritem.label}

        # if page does not exists. add 
        if([string]::IsNullOrEmpty($pgExists))
        {
            # add page to work item and add all groups , fields and controls
            [pscustomobject]$addPage = @{
                    id = ""
                    label = $Curritem.label.Trim()   
                    order = $null
                    visible = $true
                    pageType = $null                                                      
                }    
            
            $secJson = ConvertTo-Json -InputObject $addPage
            $pageURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + '/layout/pages?api-version=7.1-preview.1'   
            $page = Invoke-RestMethod -Uri $pageURL -Method Post -ContentType "application/json" -Headers $authorization -Body $secJson
            Write-Host $page
        }
    }

    # refresh pages in new work item. when new process is created it has default pages. after we add pages need to get work item type again to get all new pages
    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
    $newWKItemList = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
    $newWKItem =  $newWKItemList.value | Where-Object {$_.name -eq $NewWorkItemName}
    
    # get pages from new work item type. needed to add groups to page.
    # Each page has 4 sections that are created on page creation. They are situated left to right on page. section 4 i believe is hidden (not sure yet)
    $newPages = $newWKItem.layout.pages

If you notice after I add all the pages I go back and get the new work item again. This way I now have the variable $newWKItem with all the pages added. Now it’s just a matter of looping thru the pages in the layout and adding the fields. 
Well, it’s not really just that easy. There are a few undocumented pieces of this puzzle that need to be addressed. In my research I have identified two fields in the layout that need special attention. In this endeavor I am not looking at any of the System field except for the description multi line field. By default, this field is added to the page on work item creation. So, if you for some reason renamed that field you need to deal with this field differently than the others.
The way I structured this function I get the work item type to copy from and loop through each page, each section on each page and each control in each section. The Description field will show up as the first group in the first section. Yes, I know it’s not in a group, but the pages on the work item are structured in a way that everything is in a group. This was the biggest revelation and the hardest to discover. The reason is when you look at the UI the description field does not have a group. So the real issue here is that it’s a multi-line text box (HTML). ADO handles them in a different way. First, they must always appear in the first section. Try putting a multi-line text box in another section or in a group and the UI will not allow it. I get it, to format a multi-line text box in the other sections, which are narrower would be programmer hell. Now that we know these fields need to be handled differently it ‘s just a matter of figuring out how.
The System.Description field is the easiest of the two to deal with. Here all you need to do is edit the group its associated with and update the label and visibility. You need only to grab the id of the group and create a request with the id, label, and visibility as shown below. A few things to note here in the code. First the label field you noticed I removed the leading and trailing blanks. If you don’t the request fails. This is not in any of the documentation, I found it because one of my fields had a trailing blank. Second, the visibility field  or any field that is either True, False, or Null must be encapsulated in quotes. Without the quotes, PowerShell give it a value of $true instead of “True”. This only took a few failed calls to figure out the request was wrong. Be careful the error messages from the API do not always point to the problem.
 # if this is the system description field, need to update label and visibility
if($grp.controls[0].id -eq "System.Description")
{
    $editGrp = @{
     id = $newGrp.Id
     label = $grp.label.Trim()
     visible = if($grp.controls[0].visible -eq "true"){"$true"}else{"$false"}
    }

    $editJSON = ConvertTo-Json -InputObject $editGrp
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/groups/update?view=azure-devops-rest-7.1
    # PATCH https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups/{groupId}?api-version=7.1-preview.1
    $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id +  "/groups/" + grp.id + "?api-version=7.1-preview.1”
    $editGroup = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
    Write-Host $editGroup
}

Ok that one was easy. How about the multi-line text box somewhere else on the page? Now that is where we start to lose our hair and go gray. Again, remember everything needs to be in a group, but this field is not in a group when you look at it in the UI. So after a few hours digging through fiddler traffic I was able to find what was not documented regarding multi-line text fields. You must create a group and add the multi-line field as a control in the group.  This was the piece of the puzzle I was missing. I found the request that was being sent when a multi-line field got placed on the page and was able to figure out what they were going.  Now granted the documentation on adding a group does show that a control can be part of the request, but it doesn’t specify that multi-line text fields are a special case. 
The steps to create it are as follows: 
First you must add the field to the work item type. Once the field is part of the work item type then you can add the group to the section as shown in the code below. First some clarity, the variable $grp is the control in the work item to copy from that we are looping through the groups for the given section. I first add the field to the new work item type. Then I add the new group to the section. Note that almost everything is null except for the label in the group which will become the label for the field. In the control we have a reference to the field we just added to the work item (id field in control) and the label for the control. Then it’s just add the group using the API as seen at the end of this code block.

  # multi line text fields cannot be inside a group. they are their own group on the UI
if($grp.controls[0].controlType -eq "HtmlFieldControl")
{
  isMultiLine = $true
  # first add the field to the work item
  $addCtl = @{
     referenceName = $grp.controls[0].id
     order = "$null"
     readOnly = "$false"
     label = $grp.label.Trim()
     visible = "$true"

     # must encapsulate true false in quotes to register
     defaultValue = if($fld.type -eq "boolean"){"$false"}else {""}
     required = if($fld.type -eq "boolean"){"$true"}else {"$false"}                                                    
   }
   $ctlJSON = ConvertTo-Json -InputObject $addCtl

   # add field to work item type
   # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/fields/add?view=azure-devops-rest-7.1
   # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/fields?api-version=7.1-preview.2
   $field = $null
   $fieldURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemTypes/" + $newWKItem.referenceName + "/fields?api-version=7.1-preview.2"
   $field = Invoke-RestMethod -Uri $fieldURL -Method Post -ContentType "application/json" -Headers $authorization -Body $ctlJSON
   Write-Host $field
                                            
  # now add the Multi line field to the page in a group with no name 
  $addGroup = @{
            Contribution = "$null"    
            height = "$null"
            id = "$null"
            inherited = "$null"
            isContribution = "$false"
            label = $grp.label.Trim()
            visible = "$true"
            order = "$null"
            overridden = "$null"
                 controls = @( @{
                     contribution = "$null"
                     controlType = "$null"
                     height = "$null"
                     id = $grp.controls[0].id
                     inherited = "$null"
                     isContribution = "$false"
                     label = $grp.controls[0].label.Trim()
                     metadata = "$null"
                     order = "$null"
                     overridden = "$null"
                     visible = "$true"
                     watermark = "$null"
                 })
                                                                                            
  }
  $grpJSON = ConvertTo-Json -InputObject $addGroup
  # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups?api-version=7.1-preview.1
  $groupURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id + "/groups?api-version=7.1-preview.1"   
  $group = Invoke-RestMethod -Uri $groupURL -Method Post -ContentType "application/json" -Headers $authorization -Body $grpJSON
  Write-Host "Multi line field " $group
  $newGrp = $group

}

There are a few other controls you need to deal with. First id the control extension field. This is a control that is a multi-select and has the ability to add selections. In order to add this type of field to the page you have to add the field to the work item as with all the fields. Then you add the group it goes under and lastly you add the control to the group. The request is shown below. Note that you must add an Id to the control that’s unique. I used the PowerShell function New-Guid. Next you must add a reference name. This is the id of the field you just added. Then in the contribution section you add the field Name and values again.

  # add control to group. add the field to the control
                                            if($grpCtl.isContribution -eq $true)
                                            {
                                                $addCtl = @{

                                                    # un documented when adding a contribution control it must have an ID. it has to be unique so i added a guid.
                                                    id = New-Guid

                                                    # un documented - if adding a contribution field must add reference name - this is the field in the control
                                                    referenceName = $grpCtl.contribution.inputs.FieldName

                                                    isContribution =  if($grpCtl.isContribution -eq $true){"$true"}else {"$false"}  
                                                    height = "$null"
                                                    label = $grpCtl.label.Trim()
                                                    metadata = "$null"
                                                    order = "$null"
                                                    overridden = "$null"
                                                    readOnly = if($grpCtl.readOnly -eq $true){"$true"}else {"$false"}   
                                                    visible = if($grpCtl.visible -eq $true){"$true"}else {"$false"}   
                                                    watermark = "$null"
                                                    contribution = @{
                                                        contributionId = $grpCtl.contribution.contributionId
                                                        inputs = @{
                                                            FieldName =  $grpCtl.contribution.inputs.FieldName
                                                            Values = $grpCtl.contribution.inputs.Values
                                                        }
                                                    }
                                                }
                                            }

The other field type to watch out for is a Boolean field. The key here is it must include a default value. If you omit the default value, it will not add to the page. The way I got around this was always including the default value and if the field type was Boolean, I set it to False. If it was not Boolean, I set it to a blank string and that seems to work.
Azure DevOps is a powerful tool and the API’s give you the ability to do some very interesting things. Unfortunately, not everything in the API’s is documented so it requires some perseverance and some time luck to find what you need.  We started this article with the good news and bad news. I hope I was able to help you understand the bad news. The Azure DevOps API’s are awesome, but they just lack some clarity in the nuances of some specific cases. Unfortunately those cases are the difference between things working and not, but hey no one is perfect, but I still believe these API’s are the most powerful tools when it comes to enhancing Azure DevOps.

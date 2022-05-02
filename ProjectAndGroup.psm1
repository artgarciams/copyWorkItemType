#
# FileName : ProjectAndGroup.psm1
# Data     : 02/09/2018
# Purpose  : this module will create a project and groups for a project
#           This script is for demonstration only not to be used as production code
#
# last update 12/04/2020

function GetVSTSCredential () {
    Param(
        $userEmail,
        $Token
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userEmail, $token)))
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo)}
}

function Copy-ProcessAndWorkItemType()
{
    Param(
        [Parameter(Mandatory = $false)]
        $userParams,
      
        [Parameter(Mandatory = $true)]      
        $InheritedProcessName,

        [Parameter(Mandatory = $true)]      
        $DestinationProcess,

        [Parameter(Mandatory = $true)]      
        $NewWorkItemName,

        [Parameter(Mandatory = $true)]      
        $WorkItemToCopy

    )

    $authorization = GetVSTSCredential -Token $userParams.PAT -userEmail $userParams.userEmail        

    # get all processes
    # GET https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
    $AllProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
    $AllProcesses = Invoke-RestMethod -Uri $AllProcessesUrl -Method Get -Headers $authorization
    
    # find inherited process - process to copy
    $inheritProc =  $AllProcesses.value | Where-Object {$_.name -eq $InheritedProcessName}
    
    # see if new process exists
    $proc =  $AllProcesses.value | Where-Object {$_.name -eq $DestinationProcess}

    # if new process does not exist add it
    if([string]::IsNullOrEmpty($proc) )
    {
        # create new process
        # POST https://dev.azure.com/{organization}/_apis/work/processes?api-version=7.1-preview.2
        $processJson = @{
            description  =  "New process added with PowerShell"
            name = $DestinationProcess
            parentProcessTypeId = $inheritProc.parentProcessTypeId
        }
        $newProcess = ConvertTo-Json -InputObject $processJson
        $newProcessesUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes?api-version=7.1-preview.2"     
        $proc = Invoke-RestMethod -Uri $newProcessesUrl -Method Post -ContentType "application/json" -Headers $authorization -Body $newProcess
    }

    #
    # now confirm new process work item exists if not add ite
    #
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2
    $findWkProcessUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId + "/workitemtypes" + '?$expand=layout&api-version=7.1-preview.2' 
    $findWkProcess = Invoke-RestMethod -Uri $findWkProcessUrl -Method Get -Headers $authorization 
    $newWKItem = $findWkProcess.value | Where-Object {$_.name -eq $NewWorkItemName}

    # get work item types to inherit from
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/work-item-types/list?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workitemtypes?api-version=7.1-preview.2    
    $AllWorkItemTypeUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $inheritProc.typeId + '/workitemtypes?$expand=layout&api-version=7.1-preview.2'      
    $AllWorkItemTypes = Invoke-RestMethod -Uri $AllWorkItemTypeUrl -Method Get -Headers $authorization
    $WorkItemType =  $AllWorkItemTypes.value | Where-Object {$_.name -eq $WorkItemToCopy}

    # new process work item type does not exist add it
    if([string]::IsNullOrEmpty($newWKItem) )
    {
        # create work item type within new precess
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

    # get pages from new work item type. needed to add groups to page.
    # each page has 4 sections that arte created on page creation.they are situated left to right on page. section 4 i believe is hidden( not sure yet)
    $newPages = $newWKItem.layout.pages
  
    # find all fields in work item type need to handle boolean and other fields
    # this is a list of all the fileds in the org
    # https://docs.microsoft.com/en-us/rest/api/azure/devops/wit/fields/get?view=azure-devops-rest-7.1
    # GET https://dev.azure.com/{organization}/{project}/_apis/wit/fields?api-version=7.1-preview.2
    $AllFieldsUrl = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + '/_apis/wit/fields?$expand=extensionFields&api-version=7.1-preview.2'
    $AllFields = Invoke-RestMethod -Uri $AllFieldsUrl -Method Get -Headers $authorization
    Write-Host $AllFields

    # loop thru layout to copy and add pages  to new layout if they dont exist
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
    # each page has 4 sections that arte created on page creation.they are situated left to right on page. section 4 i believe is hidden( not sure yet)
    $newPages = $newWKItem.layout.pages

    # loop thru inherited work item to copy to new work item
    foreach ($Curritem in $WorkItemType.layout.pages) 
    {      
        $pgExists = $newPages | Where-Object {$_.label.Trim() -eq $Curritem.label.Trim()}
        
        # if page exists. add groupd that are missing and add fileds to groups
        if($pgExists -ne $null)
        {
            # if inherited page is visible, add group info  if missing
            if($Curritem.visible -eq $true)
            {
                #  loop thru each section in inherited work item and then loop thru
                # each section in new work item and add groups to new work item if they are not there
                foreach ($currSection in $Curritem.sections) 
                {
                    # loop thru each new section and add groups as needed
                    foreach ($newSection in $pgExists.sections) 
                    {
                        # find inhertited section and go thru groups
                        if( $currSection.id -eq $newSection.id)
                        {                         
                            # loop thru each group in inherited page and add any group that does not exist
                            foreach ($grp in $currSection.groups) 
                            {
                                    # special case if we rename system.description need to handle it this way
                                    $newGrp = $null
                                    $isMultiLine = $false
                                    if($grp.controls[0].id -eq "System.Description")
                                    {
                                        # does new group exist if its one of the default fields we need to look for them first
                                        $newGrp = $newSection.groups | Where-Object {$_.id -eq $grp.id}        
                                    }
                                    else
                                    {
                                        # does new group exist if its one of the default fields we need to look for them first
                                        $newGrp = $newSection.groups | Where-Object {$_.label.Trim() -eq $grp.label.Trim()}    
                                        
                                         # multi line text fields cannot be inside a group. they are their own group on the UI
                                        if($grp.controls[0].controlType -eq "HtmlFieldControl")
                                        {
                                            $isMultiLine = $true

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
                                    }     

                                    # if group does not exist add it
                                    if([string]::IsNullOrEmpty($newGrp) -and $isMultiLine -eq $false )
                                    {
                                        $addGroup = @{
                                            id = "$null"
                                            label = $grp.label.Trim()
                                            visible = "$true"
                                            isContribution = "$false"
                                            
                                        }
                                        $grpJSON = ConvertTo-Json -InputObject $addGroup

                                        # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups?api-version=7.1-preview.1
                                        $groupURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id + "/groups?api-version=7.1-preview.1"   
                                        $group = Invoke-RestMethod -Uri $groupURL -Method Post -ContentType "application/json" -Headers $authorization -Body $grpJSON
                                        Write-Host $group

                                        foreach ($grpCtl in $grp.controls) 
                                        {
                                            $fld = $AllFields.value | Where-Object {$_.referenceName -eq $grpCtl.id }
                                            if($fld.type -eq "html")
                                            {
                                                Write-Host $fld
                                            }

                                            # add controls to group 
                                            if($grpCtl.isContribution -eq $true)
                                            {
                                                $addCtl = @{  
                                                    referenceName = $grpCtl.contribution.inputs.FieldName                                                    
                                                    order = "$null"
                                                    readOnly = "$false"
                                                    inherited = $grpCtl.inherited
                                                    label = $grpCtl.label.Trim()
                                                    visible = "$true"

                                                    # must encapsulate true false in quotes to register                                                
                                                    required = if($grpCtl.controlType -eq "boolean"){"$true"}else {"$false"}  
                                                    contribution = @{
                                                        contributionId = $grpCtl.contribution.contributionId
                                                        inputs = @{
                                                            FieldName =  $grpCtl.contribution.inputs.FieldName
                                                            Values = $grpCtl.contribution.inputs.Values
                                                        }
                                                    }
                                                    isContribution = "$true"
                                                }
                                            }
                                            else
                                            {
                                                $addCtl = @{
                                                    referenceName = $grpCtl.id
                                                    order = "$null"
                                                    readOnly = "$false"
                                                    label = $grpCtl.label.Trim()
                                                    visible = "$true"
                                                    # must encapsulate true false in quotes to register
                                                    defaultValue = if($fld.type -eq "boolean"){"$false"}else {""}
                                                    required = if($fld.type -eq "boolean"){"$true"}else {"$false"}                                                    
                                                }
                                            }
                                            $ctlJSON = ConvertTo-Json -InputObject $addCtl

                                            # add field to work item type
                                            # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/fields/add?view=azure-devops-rest-7.1
                                            # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/fields?api-version=7.1-preview.2
                                            $field = $null
                                            $fieldURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemTypes/" + $newWKItem.referenceName + "/fields?api-version=7.1-preview.2"
                                            $field = Invoke-RestMethod -Uri $fieldURL -Method Post -ContentType "application/json" -Headers $authorization -Body $ctlJSON
                                            Write-Host $field

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
                                            else
                                            {
                                                $addCtl = @{
                                                    id = $grpCtl.id
                                                    isContribution = if($grpCtl.isContribution -eq $true){"$true"}else {"$false"}  
                                                    height = "$null"                                                    
                                                    label = $grpCtl.label.Trim()
                                                    metadata = "$null"
                                                    order = "$null"
                                                    overridden = "$null"
                                                    readOnly = if($grpCtl.readOnly -eq $true){"$true"}else {"$false"}   
                                                    visible = if($grpCtl.visible -eq $true){"$true"}else {"$false"}   
                                                    watermark = "$null"
                                                }
                                            }

                                            $ctlJSON = ConvertTo-Json -InputObject $addCtl
                                            # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/controls/create?view=azure-devops-rest-7.1
                                            # POST https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/groups/{groupId}/controls?api-version=7.1-preview.1
                                            $controlURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/groups/" + $group.id + "/controls?api-version=7.1-preview.1"    
                                            $control = Invoke-RestMethod -Uri $controlURL -Method Post -ContentType "application/json" -Headers $authorization -Body $ctlJSON
                                            Write-Host $control
                                        }
                                    
                                    }                                    
                                    else 
                                    {   
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
                                            $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id +  "/groups/" + $grp.id + "?api-version=7.1-preview.1"    
                                            $editGroup = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
                                            Write-Host $editGroup

                                        }
                                        else
                                        {
                                            # if not a multi line control then update the group
                                            if($grp.controls[0].controlType -ne "HtmlFieldControl")
                                            {                                            
                                                # group exists update the group deployment and development groups inherited and trying to hide
                                                    $editGrp = @{
                                                        id = $newGrp.Id
                                                        label = $grp.label.Trim()
                                                        visible = if($grp.controls[0].visible -eq "true"){"$true"}else{"$false"}
                                                    }
                                                $editJSON = ConvertTo-Json -InputObject $editGrp

                                                # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/groups/update?view=azure-devops-rest-7.1
                                                # PATCH https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages/{pageId}/sections/{sectionId}/groups/{groupId}?api-version=7.1-preview.1
                                                $editGrp = $null
                                                $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages/" + $pgExists.id + "/sections/" + $newSection.id +  "/groups/" + $grp.id + "?api-version=7.1-preview.1"    
                                                $editGroup = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
                                                Write-Host $editGroup
                                            }
                                        
                                        }
                                       
                                    
                                    }

                            }
                        }
                    }
                }
                
            } # group visible
            else
            {
                # page visible is false hide page in new layout
                $editPg = @{
                    id = $pgExists.id
                    label = $pgExists.label.Trim()
                    visible = "$false"
                }
                $editJSON = ConvertTo-Json -InputObject $editPg

                # https://docs.microsoft.com/en-us/rest/api/azure/devops/processes/pages/update?view=azure-devops-rest-7.1
                # PATCH https://dev.azure.com/{organization}/_apis/work/processes/{processId}/workItemTypes/{witRefName}/layout/pages?api-version=7.1-preview.1
                $editURL = $userParams.HTTP_preFix + "://dev.azure.com/" + $userParams.VSTSMasterAcct + "/_apis/work/processes/" + $proc.typeId  + "/workitemtypes/" + $newWKItem.referenceName + "/layout/pages?api-version=7.1-preview.1"    
                $editPage = Invoke-RestMethod -Uri $editURL -Method PATCH -ContentType "application/json" -Headers $authorization -Body $editJSON
                Write-Host $editPage
            }

        } # page exists
       

    }

   
   
    $pages = 1
   
  
    
    # 

}
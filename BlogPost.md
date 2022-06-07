		
# COPY A WORK ITEM TYPE USING AZURE DEVOPS API’s

So, we all love how we can manage engagements in Azure DevOps (ADO). We can create Epics, Features, User Stories and track our progress on Kanban boards. You can customize work item types to suit the needs of your business and project with ease. So, what if you just want to copy the work item types? There is no way to copy the existing work item to a new work item type. If you only have a few fields, well that’s no big deal, but if you have multiple pages, multiple groups on the page and multiple fields in the groups that becomes a monumental task.

In this article I will explain how to copy a work item using the Azure DevOPs API’s. The documentation shows you how to do the basics of adding a new process, adding a work item type, and adding groups and such but there are a few things missing. 

The steps we will follow are:
-	Create new work item type
-	Create pages for new work item type by looping through target work item type and adding missing pages
-	Create stages for new work item type
  - Remove any default stages not in copy from work item
-	Loop through each page in target work item type
  -	Loop through each section in each page
    -	Loop thru each group in each section
      -	Loop through each control in each group
        -	Add field to new work item type (a control holds only 1 field from what I have seen)
        -	Add group to given section
        -	Add control to given group
  
This is how the code is structured. 

Once the new work item type is created you then need to add the stages from the work item you are copying from. This will give you the basic Work Item type with the states added from the work item target. Once the work item type is created by default it will have one page and four sections. From Left to right the first three sections reflect the three columns on the page. I have yet to figure out what the fourth section. By adding the work item types it makes it somewhat easier to add the fields. You just look through each page in the layout and add the fields.

There are a few undocumented pieces of this puzzle that need to be addressed and a few field types that require special attention. By default, the System.Description field is added to the page on work item creation. So, if you for some reason renamed that field you need to deal with this field differently than the others. 
The Description field will show up as the first group in the first section. This was the biggest revelation and the hardest to discover. The reason is when you look at the UI the description field does not have a group. So, the real issue here is that it’s a multi-line text box (HTML). 

How about the multi-line text box somewhere else on the page? Again, remember everything needs to be in a group, but this field is not in a group when you look at it in the UI. So, after a few hours digging through fiddler traffic, I was able to find what was not documented regarding multi-line text fields. You must create a group and add the multi-line field as a control in the group.  This was the piece of the puzzle I was missing. I found the request that was being sent when a multi-line field got placed on the page and was able to figure out what they were going.  Now granted the documentation on adding a group does show that a control can be part of the request, but it doesn’t specify that multi-line text fields are a special case. 

The steps to create it are as follows: 

First you must add the field to the work item type. Once the field is part of the work item type then you can add the group to the section as shown in the code below. First some clarity, the variable $grp is the control in the work item to copy from that we are looping through the groups for the given section. I first add the field to the new work item type. Then I add the new group to the section. Note that almost everything is null except for the label in the group which will become the label for the field. In the control we have a reference to the field we just added to the work item (id field in control) and the label for the control. 

Then it’s just add the group using the API as seen at the end of this code block.

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
       defaultValue = if($fld.type -eq "boolean")
                        {"$false"}
                        else {""}
       required = if($fld.type -eq "boolean")
                     {"$true"} 
                     else {"$false"} 
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
    


There are a few other controls you need to deal with. First id the control extension field. This is a control that is a multi-select and could add selections. To add this type of field to the page you must add the field to the work item as with all the fields. Then you add the group it goes under and lastly you add the control to the group. The request is shown below. Note that you must add an Id to the control that’s unique. I used the PowerShell function New-Guid. Next you must add a reference name. This is the id of the field you just added. Then in the contribution section you add the field Name and values again.

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
          
The other field type to watch out for is a Boolean field. The key here is it must include a default value. If you omit the default value, it will not be added to the page. The way I got around this was always including the default value and if the field type was Boolean, I set it equal False. If it was not Boolean, I set it to a blank string and that seems to work.

I have shown you how you can take an existing work item type and make a copy in the same process. This should work if you want to create a new work item in another process as well. The source for this is listed on my [GitHub account](https://github.com/artgarciams/copyWorkItemType). 

I hope this helps clear up some of the confusion around copying work item types and that this was in some way helpful. If you have any questions, please feel free to reach out arthur.garcia@microsoft.com 
Thanks, and happy coding

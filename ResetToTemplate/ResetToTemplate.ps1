<#
   Copyright 2016 OSIsoft, LLC.
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at
       http://www.apache.org/licenses/LICENSE-2.0
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
#>
param(
    [Parameter(Position=0,Mandatory=$false)]
    [string] $AFServerName = "localhost",
    
    [Parameter(Position=1,Mandatory=$false)]
    [string] $AFDatabaseName
)

[Reflection.Assembly]::LoadFile('C:\Program Files (x86)\PIPC\AF\PublicAssemblies\OSIsoft.AFSDK.dll')

function ResetAttributeAndChildAttributeToTemplate ($AFAttrs)
{
    if($AFAttrs.Template -ne $null -and $AFAttrs.IsConfigurationItem -eq $false)     #If the attribute belongs to a template & Not a Configuration Item
    {
        try
        {
        $Success = $AFAttrs.ResetToTemplate();                            #Reset the values to Template values.
        }
        catch [InvalidOperationException]
        {
            # Can occur if the element is checked out by somebody
        }
        # if there is a pi point created
        if($Success -and $AFAttrs.DataReference -ne $null)                   #If it has an Data Reference,
        {
            try
            {
                $AFAttrs.DataReference.CreateConfig();
            }
            catch  [InvalidOperationException]
            {
                # Can occurs if the specified find PI Server cannot be reached
            }
            catch [System.Collections.Generic.KeyNotFoundException]
            {
                #From the documentation: This exception is thrown when the specified name is not found in the cache of loaded PIPoint attributes.
            }
        }
    }
    foreach($Child in $AFAttrs.Attributes)                  #For all the SubAttributes of this Attribute.
    {
        ResetAttributeAndChildAttributeToTemplate($Child)                                #Call its own function for each and every SubAttributes.
    }
}

function ResetAllElements($AFDatabase) {
    Write-Host "Will reset database: " $AFDatabase
    $AFElements = [OSIsoft.AF.Asset.AFElement]::FindElements($AFDatabase, $null, "*", [OSIsoft.AF.AFSearchField]::Name, $true, [OSIsoft.AF.AFsortField]::Name, [OSIsoft.AF.AFSortOrder]::Ascending,10000)

    foreach($AFElement in $AFElements)
    {
        #write-output $AFElement.Name
        foreach($AFAttribute in $AFElement.Attributes)
        {
            ResetAttributeAndChildAttributeToTemplate($AFAttribute)
        }
        $AFElement.CheckIn()	
    }
}

$PISystems = new-object OSIsoft.AF.PISystems
$PISystem = $PISystems[$AFServerName]
if($AFDatabaseName)
{
    $AFDatabase = $PISystem.Databases[$AFDatabaseName]
    ResetAllElements($AFDatabase)
}
else
{
    foreach($AFDatabase in $PISystem.Databases) {
        ResetAllElements($AFDatabase)
    }
}
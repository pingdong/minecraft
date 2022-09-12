targetScope = 'subscription'

// **********************
// *     Parameters     *
// **********************

// Project Related Parameters
@minLength(3)
param resourceGroupName string

// Resource Related Parameters
@minLength(3)
param location string

@description('Default Resource Tags')
param defaultTags object = {
  project: resourceGroupName
}

// **********************
// *     Resources      *
// **********************

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: defaultTags
}

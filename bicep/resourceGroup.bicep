targetScope = 'subscription'

// **********************
// *     Parameters     *
// **********************

@minLength(3)
param project string

@minLength(3)
param resourceGroupName string
@minLength(3)
param location string

@description('Default Resource Tags')
param defaultTags object = {
  project: project
  owner: 'Ping Dong'
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

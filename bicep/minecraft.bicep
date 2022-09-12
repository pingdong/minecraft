// **********************
// *     Parameters     *
// **********************

// Project Related Parameters
@minLength(3)
param project string

@description('Minecraft worlds')
param worlds array

// Resource Related Parameters
@minLength(3)
param location string = resourceGroup().location

@description('Default Resource Tags')
param defaultTags object = {
  project: project
  owner: 'Ping Dong'
}

// **********************
// *     Resources      *
// **********************

// Storage Account
resource sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: 'saminecraftdata'
  location: location
  tags: defaultTags
   
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    accessTier: 'Hot'
    largeFileSharesState: 'Enabled'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}
resource fileservices 'Microsoft.Storage/storageAccounts/fileServices@2022-05-01' = {
  name: 'default'
  parent: sa
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
  }  
}
resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = [for world in worlds: {
  name: '${world}'
  parent: fileservices
  properties: {
    shareQuota: 1024
    accessTier: 'Hot'
  }
}]

// Container Instance
resource ci 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = [for world in worlds: {
  name: 'aci-minecraft-${world}'
  location: location
  tags: defaultTags

  dependsOn: fileshare

  properties: {
    containers: [
      {
        name: '${world}'
        properties: {
          image: 'itzg/minecraft-bedrock-server:latest'
          resources: {
            requests: { cpu: 1, memoryInGB: 2 }
          }
          environmentVariables: [
            { name: 'EULA', value: 'TRUE' }
            { name: 'GAMEMODE', value: '1' }
            { name: 'DIFFICULTY', value: '0' }
          ]
          ports: [
            { port: 19132, protocol: 'UDP' }
          ]
          volumeMounts: [
            { name: 'datavolume', mountPath: '/data' }
          ]
        }
      }
    ]
    restartPolicy: 'OnFailure'
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        { port: 19132, protocol: 'UDP' }
      ]
      dnsNameLabel: 'mcs-${world}'
    }
    volumes: [
      {
        name: 'datavolume'
        azureFile: {
          shareName: '${world}'
          storageAccountName: sa.name
          storageAccountKey: sa.listKeys().keys[0].value
        }
      }
    ]
  }
}]

// API Connection
resource api 'Microsoft.Web/connections@2016-06-01' = {
  name: 'aci'
  location: location
  
  properties: {
    displayName: 'Azure Container Instance'
    api: {
      id: '${subscription().id}/providers/Microsoft.Web/locations/${location}/managedApis/aci'
    }
  }
}

// Logic App
resource la 'Microsoft.Logic/workflows@2019-05-01' = [for world in worlds: {
  name: 'la-minecraft-start'
  location: location
  tags: defaultTags

  dependsOn: [
    api
  ]

  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      triggers: {
        recurrence: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Day'
            interval: 1
            schedule: {
              hours: [
                '16'
              ]
            }
            timeZone: 'New Zealand Standard Time'
          }
        }
      }
      actions: {
        'start_container': {
          type: 'ApiConnection'
          inputs: {
            input: {
              host: {
                connection: {
                  name: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/aci'
                }
              }
              method: 'post'
              path: '/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ContainerInstance/containerGroups/${world}/start'
              queries: {
                'x-ms-api-version': '2019-12-01'
              }
            }
          }
        }
      }
    }
  }
}]

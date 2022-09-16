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

param aciPrefix string = 'aci-minecraft-'
param aciDNSPrefix string = 'mcs-'

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
resource aci 'Microsoft.ContainerInstance/containerGroups@2021-10-01' = [for world in worlds: {
  name: '${aciPrefix}${world}'
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
      dnsNameLabel: '${aciDNSPrefix}${world}'
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
resource arm 'Microsoft.Web/connections@2016-06-01' = {
  name: 'arm'
  location: location
  kind: 'V1'
  
  properties: {
    displayName: 'Azure Container Instance'
    statuses: [
      {
        status: 'Connected'
      }
    ]
    api: {
      name: 'arm'
      displayName: 'Azure Resource Manager'
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/arm'
      type: 'Microsoft.Web/locations/managedApis'
    }
  }
}

// Logic App
resource la_start 'Microsoft.Logic/workflows@2019-05-01' = [for world in worlds: {
  name: 'la-${world}-start'
  location: location
  tags: defaultTags

  dependsOn: [
    arm
  ]

  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {
          }
          type: 'Object'
        }
      }
      triggers: {
        recurrence: {
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
          type: 'Recurrence'
        }
      }
      actions: {
        Invoke_resource_operation: {
          runAfter: {
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'arm\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/subscriptions/@{encodeURIComponent(\'${subscription().subscriptionId}\')}/resourcegroups/@{encodeURIComponent(\'${resourceGroup().name}\')}/providers/@{encodeURIComponent(\'Microsoft.ContainerInstance\')}/@{encodeURIComponent(\'containerGroups/${aciPrefix}${world}\')}/@{encodeURIComponent(\'start\')}'
            queries: {
              'x-ms-api-version': '2019-12-01'
            }
          }
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          arm: {
            connectionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/arm'
            connectionName: 'arm'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/arm'
          }
        }
      }
    }
  }
}]

resource la_stop 'Microsoft.Logic/workflows@2019-05-01' = [for world in worlds: {
  name: 'la-${world}-stop'
  location: location
  tags: defaultTags

  dependsOn: [
    arm
  ]

  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {
          }
          type: 'Object'
        }
      }
      triggers: {
        recurrence: {
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
          type: 'Recurrence'
        }
      }
      actions: {
        Invoke_resource_operation: {
          runAfter: {
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'arm\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/subscriptions/@{encodeURIComponent(\'${subscription().subscriptionId}\')}/resourcegroups/@{encodeURIComponent(\'${resourceGroup().name}\')}/providers/@{encodeURIComponent(\'Microsoft.ContainerInstance\')}/@{encodeURIComponent(\'containerGroups/${aciPrefix}${world}\')}/@{encodeURIComponent(\'stop\')}'
            queries: {
              'x-ms-api-version': '2019-12-01'
            }
          }
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          arm: {
            connectionId: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/connections/arm'
            connectionName: 'arm'
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/arm'
          }
        }
      }
    }
  }
}]

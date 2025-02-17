@sys.description('The environment type (nonprod or prod)')
@allowed([
  'nonprod'
  'prod'
])
param environmentType string = 'nonprod'
@sys.description('The PostgreSQL Server name')
@minLength(3)
@maxLength(24)
param postgreSQLServerName string = 'ie-bank-db-server-dev'
@sys.description('The PostgreSQL Database name')
@minLength(3)
@maxLength(24)
param postgreSQLDatabaseName string = 'ie-bank-db'
@sys.description('The App Service Plan name')
@minLength(3)
@maxLength(24)
param appServicePlanName string = 'ie-bank-app-sp-dev'
@sys.description('The Web App name (frontend)')
@minLength(3)
@maxLength(24)
param appServiceAppName string = 'ie-bank-dev'
@sys.description('The API App name (backend)')
@minLength(3)
@maxLength(24)
param appServiceAPIAppName string = 'ie-bank-api-dev'
@sys.description('The name of the Azure Monitor workspace')
param azureMonitorName string
@sys.description('The name of the Application Insights')
param appInsightsName string 
@sys.description('The Azure location where the resources will be deployed')
param location string = resourceGroup().location
@sys.description('The value for the environment variable ENV')
param appServiceAPIEnvVarENV string
@sys.description('The value for the environment variable DBHOST')
param appServiceAPIEnvVarDBHOST string
@sys.description('The value for the environment variable DBNAME')
param appServiceAPIEnvVarDBNAME string
@sys.description('The value for the environment variable DBPASS')
@secure()
param appServiceAPIEnvVarDBPASS string
@sys.description('The value for the environment variable DBUSER')
param appServiceAPIDBHostDBUSER string
@sys.description('The value for the environment variable FLASK_APP')
param appServiceAPIDBHostFLASK_APP string
@sys.description('The value for the environment variable FLASK_DEBUG')
param appServiceAPIDBHostFLASK_DEBUG string

param staticSiteName string 
param acrname string 
param appServicePlanNamedtest string
param sku object
param keyVaultName string
param logAnalyticsWorkspace string 
targetScope = 'resourceGroup'
param acrSku string = 'Basic'

resource postgresSQLServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgreSQLServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: 'iebankdbadmin'
    administratorLoginPassword: 'IE.Bank.DB.Admin.Pa$$'
    createMode: 'Default'
    highAvailability: {
      mode: 'Disabled'
      standbyAvailabilityZone: ''
    }
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    version: '15'
  }

  resource postgresSQLServerFirewallRules 'firewallRules@2022-12-01' = {
    name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
    properties: {
      endIpAddress: '0.0.0.0'
      startIpAddress: '0.0.0.0'
    }
  }
}

resource postgresSQLDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  name: postgreSQLDatabaseName
  parent: postgresSQLServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

module appService 'modules/app-service.bicep' = {
  name: 'appService'
  params: {
    location: location
    environmentType: environmentType
    appServiceAppName: appServiceAppName
    appServiceAPIAppName: appServiceAPIAppName
    appServicePlanName: appServicePlanName
    appServiceAPIDBHostDBUSER: appServiceAPIDBHostDBUSER
    appServiceAPIDBHostFLASK_APP: appServiceAPIDBHostFLASK_APP
    appServiceAPIDBHostFLASK_DEBUG: appServiceAPIDBHostFLASK_DEBUG
    appServiceAPIEnvVarDBHOST: appServiceAPIEnvVarDBHOST
    appServiceAPIEnvVarDBNAME: appServiceAPIEnvVarDBNAME
    appServiceAPIEnvVarDBPASS: appServiceAPIEnvVarDBPASS
    appServiceAPIEnvVarENV: appServiceAPIEnvVarENV
  }
  dependsOn: [
    postgresSQLDatabase
  ]
}

output appServiceAppHostName string = appService.outputs.appServiceAppHostName

//For monitoring purposes
resource azureMonitor 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: azureMonitorName
  location: location
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', azureMonitorName)
  }
} 

module staticSite 'ResourceModules-main 2/modules/web/static-site/main.bicep' = {
  name: staticSiteName
  params: {
    // Required parameters
    name: 'static-site-team-3'
    location: location

    // Configuration for front-end framework
    buildProperties: {
      vue: {
        BuildPresets: 'Vue.js'
        appLocation: 'default'
        apiLocation: ''
        appArtifactLocation: 'default'
      }
    }
  }
}

module registry 'ResourceModules-main 2/modules/container-registry/registry/main.bicep' = {
  name: acrname
  params: {
    name: acrname
    location: location
    acrSku: acrSku
    acrAdminUserEnabled: true
  }
}

module serverfarmdev 'ResourceModules-main 2/modules/web/serverfarm/main.bicep' = {
  name: '${appServicePlanName}-deploy'
  params: {
    name: appServicePlanNamedtest
    location: location 
    sku:sku
    reserved: true
  }
}


// HERE HERE HERE

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  name: logAnalyticsWorkspace
}

resource diagnosticLogsdb 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'PostgreSQLLogs'
  scope: postgresSQLServer
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'PostgreSQLLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
  }
}


// HERE HERE HERE
module keyvault 'ResourceModules-main 2/modules/key-vault/vault/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-test-kvvmin'
  params: {
    // Required parameters
    name: keyVaultName
    location: location
}
}

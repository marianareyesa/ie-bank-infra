param location string 

module vault 'ResourceModules-main 2/modules/key-vault/vault/main.bicep' = {
  name: '${uniqueString(deployment().name, location)}-test-kvvmin'
  params: {
    name: 'kvvmin002'
    location: location
    enableVaultForDeployment: true
    roleAssignments: [
      {
        principalId: '7200f83e-ec45-4915-8c52-fb94147cfe5a'
        roleDefinitionIdOrName: 'Key Vault Secrets User'
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

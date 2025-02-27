param deploymentName string

param location string = resourceGroup().location

// For authenticating to the Marketplace API...

param aadClientId string
param aadTenantId string

@secure()
param aadClientSecret string

// For subscribing to this Mona deployment's event grid topic...

param eventGridConnectionName string = 'mona-events-connection-${deploymentName}'
param eventGridTopicName string = 'mona-events-${deploymentName}'

var name = 'mona-on-subscription-seat-qty-changed-${deploymentName}'
var displayName = 'On subscription seat quantity changed'
var description = 'This workflow is automatically triggered after Mona has been notified by the AppSource/Marketplace that a subscription seat quantity has been changed.'
var eventType = 'Mona.SaaS.Marketplace.SubscriptionSeatQuantityChanged'
var triggerName = 'When_subscription_seat_quantity_is_changed'

var actionNames = {
  parseEventInfo: 'Parse_event_information'
  parseSubscriptionInfo: 'Parse_subscription_information'
  yourIntegrationLogic: 'Add_your_integration_logic_here'
  notifyMarketplaceCondition: 'Conditional_|_Notify the Marketplace'
  notifyMarketplace: 'Notify_the_marketplace'
}

var marketplaceApiAuthAudience = '20e940b3-4c77-4b0b-9a53-9e16a1b010a7'

resource eventGridConnection 'Microsoft.Web/connections@2016-06-01' existing = {
  name: eventGridConnectionName
}

resource eventGridTopic 'Microsoft.EventGrid/topics@2021-12-01' existing = {
  name: eventGridTopicName
}

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: name
  location: location
  tags: {
    'mona:name': displayName
    'mona:description': description
    'mona:event-type': eventType
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        '${triggerName}': {
          splitOn: '@triggerBody()'
          type: 'ApiConnectionWebhook'
          inputs: {
            body: {
              properties: {
                destination: {
                  endpointType: 'WebHook'
                  properties: {
                    endpointUrl: '@{listCallbackUrl()}'
                  }
                }
                filter: {
                  includedEventTypes: [
                    eventType
                  ]
                }
                topic: eventGridTopic.id
              }
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'eventGrid\'][\'connectionId\']'
              }
            }
            path: '${subscription().id}/providers/Microsoft.EventGrid.Topics/resource/eventSubscriptions'
            queries: {
              'x-ms-api-version': '2017-06-15-preview'
            }
          }
        }
      }
      actions: {
        '${actionNames.parseEventInfo}': {
          inputs: {
            content: '@triggerBody()?[\'data\']'
            schema: {
              properties: {
                'Event ID': {
                  type: 'string'
                }
                'Event Type': {
                  type: 'string'
                }
                'Event Version': {
                  type: 'string'
                }
                'New Seat Quantity': {
                  type: 'number'
                }
                'Operation Date/Time UTC': {
                  type: 'string'
                }
                'Operation ID': {
                  type: 'string'
                }
                Subscription: {
                  type: 'object'
                }
              }
              type: 'object'
            }
          }
          runAfter: {}
          type: 'ParseJson'
        }
        '${actionNames.parseSubscriptionInfo}': {
          inputs: {
            content: '@body(\'${actionNames.parseEventInfo}\')?[\'Subscription\']'
            schema: {
              properties: {
                'Beneficiary AAD Object ID': {
                  type: 'string'
                }
                'Beneficiary AAD Tenant ID': {
                  type: 'string'
                }
                'Beneficiary Email Address': {
                  type: 'string'
                }
                'Beneficiary User ID': {
                  type: 'string'
                }
                'Is Free Trial Subscription?': {
                  type: 'boolean'
                }
                'Is Test Subscription?': {
                  type: 'boolean'
                }
                'Offer ID': {
                  type: 'string'
                }
                'Plan ID': {
                  type: 'string'
                }
                'Purchaser AAD Object ID': {
                  type: 'string'
                }
                'Purchaser AAD Tenant ID': {
                  type: 'string'
                }
                'Purchaser Email Address': {
                  type: 'string'
                }
                'Purchaser User ID': {
                  type: 'string'
                }
                'Subscription End Date': {
                  type: 'string'
                }
                'Subscription ID': {
                  type: 'string'
                }
                'Subscription Name': {
                  type: 'string'
                }
                'Subscription Start Date': {
                  type: 'string'
                }
                'Subscription Status': {
                  type: 'string'
                }
                'Subscription Term Unit': {
                  type: 'string'
                }
                'Seat Quantity': {
                  type: 'number'
                }
              }
              type: 'object'
            }
          }
          runAfter: {
            '${actionNames.parseEventInfo}': [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
        }
        '${actionNames.yourIntegrationLogic}': {
          actions: {}
          runAfter: {
            '${actionNames.parseSubscriptionInfo}': [
              'Succeeded'
            ]
          }
          type: 'Scope'
        }
        '${actionNames.notifyMarketplaceCondition}': {
          actions: {
            '${actionNames.notifyMarketplace}': {
              inputs: {
                authentication: {
                  audience: marketplaceApiAuthAudience
                  clientId: aadClientId
                  secret: aadClientSecret
                  tenant: aadTenantId
                  type: 'ActiveDirectoryOAuth'
                }
                body: {
                  status: 'Success'
                }
                headers: {
                  'content-type': 'application/json'
                }
                method: 'PATCH'
                uri: 'https://marketplaceapi.microsoft.com/api/saas/subscriptions/@{body(\'${actionNames.parseSubscriptionInfo}\')?[\'Subscription ID\']}/operations/@{body(\'${actionNames.parseEventInfo}\')?[\'Operation ID\']}?api-version=2018-08-31'
              }
              runAfter: {}
              type: 'Http'
            }
          }
          expression: {
            and: [
              {
                equals: [
                  true
                  true
                ]
              }
              {
                equals: [
                  '@body(\'${actionNames.parseSubscriptionInfo}\')?[\'Is Test Subscription?\']'
                  false
                ]
              }
            ]
          }
          runAfter: {
            '${actionNames.yourIntegrationLogic}': [
              'Succeeded'
            ]
          }
          type: 'If'
        }
      }
    }
    parameters: {
      '$connections': {
        value: {
          eventGrid: {
            connectionId: eventGridConnection.id
            connectionName: eventGridConnection.name
            id: '${subscription().id}/providers/Microsoft.Web/locations/${location}/managedApis/azureeventgrid'
          }
        }
      }
    }
  }
}

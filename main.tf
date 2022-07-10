terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "policy_demo" {
  name     = "policy_demo"
  location = "Canada Central"
}

resource "azurerm_policy_definition" "nics-no-pips" {
    name = "nics-no-pips"
    policy_type = "Custom"
    mode = "All"
    display_name = "Network interfaces should not have public IPs"
    description = "This policy denies the network interfaces which are configured with any public IP. Public IP addresses allow internet resources to communicate inbound to Azure resources, and Azure resources to communicate outbound to the internet. This should be reviewed by the network security team."

    metadata = jsonencode({
        "category": "Network",
        "version": "1.0.0"
    })

    policy_rule = jsonencode({
        "if": {
            "allOf": [
                {
                    "field": "type",
                    "equals": "Microsoft.Network/networkInterfaces"
                },
                {
                    "not": {
                        "field": "Microsoft.Network/networkInterfaces/ipconfigurations[*].publicIpAddress.id",
                        "notLike": "*"
                    }
                }
            ]
        },
        "then": {
            "effect": "deny"
        }
    })
}

resource "azurerm_subscription_policy_assignment" "nics-no-pips" {
    name = "nics-no-pips"
    policy_definition_id = azurerm_policy_definition.nics-no-pips.id
    subscription_id = data.azurerm_subscription.current.id

    non_compliance_message {
        content = "Network interfaces should not have public IPs"
    }  
}

#-----------------------------------------------------------------------------------------------------------------------
#********************** Core networking restrictions ******************** 
# This include both nics-no-pips  and close-management-ports
##----------------------------------------------------------------------------------------------------------------------


# resource "azurerm_policy_definition" "close-management-ports" {
#     name = "close-management-ports"
#     policy_type = "Custom"
#     mode = "All"
#     display_name = "Management ports should be closed on your virtual machines"
#     description = "Open remote management ports are exposing your VM to a high level of risk from Internet-based attacks. These attacks attempt to brute force credentials to gain admin access to the machine."

#     metadata = jsonencode({
#         "category": "Network",
#         "version" : "1.0.0"
#     })

#     parameters = jsonencode({
#         "effect": {
#             "type": "String",
#             "metadata": {
#                 "displayName": "Effect",
#                 "description": "Enable or disable the execution of the policy"
#             },
#             "allowedValues": [
#                 "AuditIfNotExists",
#                 "Disabled"
#             ],
#             "defaultValue": "AuditIfNotExists"
#         }
#     })

#     policy_rule = jsonencode({
#       "if": {
#         "field": "type",
#         "in": [
#           "Microsoft.Compute/virtualMachines",
#           "Microsoft.ClassicCompute/virtualMachines"
#         ]
#       },
#       "then": {
#         "effect": "[parameters('effect')]",
#         "details": {
#           "type": "Microsoft.Security/assessments",
#           "name": "bc303248-3d14-44c2-96a0-55f5c326b5fe",
#           "existenceCondition": {
#             "field": "Microsoft.Security/assessments/status.code",
#             "in": [
#               "Healthy"
#             ]
#           }
#         }
#       }
#     })  
# }

# resource "azurerm_policy_set_definition" "core_networking_restrictions" {
#     name = "core_networking_restrictions"
#     policy_type = "Custom"
#     display_name = "Core networking restrictions"

#     policy_definition_reference {
#         policy_definition_id = azurerm_policy_definition.nics-no-pips.id
#         reference_id = azurerm_policy_definition.nics-no-pips.id
#     }

#     policy_definition_reference {
#         policy_definition_id = azurerm_policy_definition.close-management-ports.id
#         reference_id = azurerm_policy_definition.close-management-ports.id      
#     } 
# }

# resource "azurerm_subscription_policy_assignment" "core_networking_restrictions" {
#     name = "core_networking_restrictions"
#     policy_definition_id = azurerm_policy_set_definition.core_networking_restrictions.id
#     subscription_id = data.azurerm_subscription.current.id

#     non_compliance_message {
#         content = "Network interfaces should not have public IPs"
#         policy_definition_reference_id = azurerm_policy_definition.nics-no-pips.id
#     }
    
#     non_compliance_message {
#         content = "Management ports should not be exposed to the public"
#         policy_definition_reference_id = azurerm_policy_definition.close-management-ports.id
#     }  
# }
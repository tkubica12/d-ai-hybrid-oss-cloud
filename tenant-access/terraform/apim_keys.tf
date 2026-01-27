# Read APIM subscription secrets (keys)
# The subscription resource doesn't return keys on creation, so we read them separately
data "azapi_resource_action" "subscription_keys" {
  for_each = local.teams

  type        = "Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview"
  resource_id = azapi_resource.apim_subscription[each.key].id
  action      = "listSecrets"
  method      = "POST"

  response_export_values = ["primaryKey", "secondaryKey"]
}

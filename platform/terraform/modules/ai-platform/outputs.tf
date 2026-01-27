output "apim_name" {
  description = "Name of the APIM instance"
  value       = azapi_resource.apim.name
}

output "apim_id" {
  description = "Resource ID of the APIM instance"
  value       = azapi_resource.apim.id
}

output "apim_gateway_url" {
  description = "Gateway URL of the APIM instance"
  value       = azapi_resource.apim.output.properties.gatewayUrl
}

output "foundry_name" {
  description = "Name of the Foundry resource"
  value       = azapi_resource.foundry.name
}

output "foundry_id" {
  description = "Resource ID of the Foundry resource"
  value       = azapi_resource.foundry.id
}

output "foundry_endpoint" {
  description = "Endpoint of the Foundry resource"
  value       = azapi_resource.foundry.output.properties.endpoint
}

output "openai_api_name" {
  description = "Name of the OpenAI API in APIM"
  value       = azapi_resource.apim_api_openai.name
}

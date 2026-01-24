# Read platform state to get infrastructure details
data "terraform_remote_state" "platform" {
  backend = "local"
  config = {
    path = var.platform_state_path
  }
}

# Convenience locals for platform outputs
locals {
  platform = {
    subscription_id     = data.terraform_remote_state.platform.outputs.subscription_id
    resource_group_name = data.terraform_remote_state.platform.outputs.resource_group_name
    resource_group_id   = data.terraform_remote_state.platform.outputs.resource_group_id
    location            = data.terraform_remote_state.platform.outputs.location

    # APIM
    apim_name        = data.terraform_remote_state.platform.outputs.apim_name
    apim_id          = data.terraform_remote_state.platform.outputs.apim_id
    apim_gateway_url = data.terraform_remote_state.platform.outputs.apim_gateway_url
    openai_api_name  = data.terraform_remote_state.platform.outputs.openai_api_name

    # Foundry
    foundry_name     = data.terraform_remote_state.platform.outputs.foundry_name
    foundry_id       = data.terraform_remote_state.platform.outputs.foundry_id
    foundry_endpoint = data.terraform_remote_state.platform.outputs.foundry_endpoint

    # AKS
    aks_name = data.terraform_remote_state.platform.outputs.aks_name
    aks_id   = data.terraform_remote_state.platform.outputs.aks_id
  }
}

# Get AKS cluster data for Helm/Kubernetes providers
data "azurerm_kubernetes_cluster" "main" {
  name                = local.platform.aks_name
  resource_group_name = local.platform.resource_group_name
}

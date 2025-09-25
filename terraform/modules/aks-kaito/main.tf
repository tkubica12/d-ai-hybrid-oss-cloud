locals {
  aks_name              = "aks-${var.base_name}"
  uai_name              = "uai-${var.base_name}"
  kaito_extension       = "kaito"
  argocd_extension_name = "argocd"
  argocd_extension_type = "Microsoft.ArgoCD"
  argocd_namespace      = "argocd"
  argocd_application_namespaces = [
    "default",
    "argocd"
  ]
  argocd_bootstrap_enabled = var.argocd_bootstrap_manifest_url != ""
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

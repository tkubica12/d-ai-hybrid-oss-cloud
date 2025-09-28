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
  aso_identity_name        = "aso-${var.base_name}"
  aso_namespace            = "azureserviceoperator-system"
  aso_service_account_name = "azureserviceoperator-default"
  aso_service_account_subject = format(
    "system:serviceaccount:%s:%s",
    local.aso_namespace,
    local.aso_service_account_name
  )
  aso_configmap_name = "platform-bootstrap-settings"
  aso_configmap_key  = "aso-values.yaml"
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

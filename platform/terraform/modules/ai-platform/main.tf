locals {
  apim_name    = "apim-${var.base_name}"
  foundry_name = "af-${var.base_name}"

  # Build model lists for unified API routing policy
  # Foundry models - names from the foundry_models list
  foundry_model_names = [for model in var.foundry_models : model.name]

  # KAITO models - keys from the kaito_models map
  kaito_model_names = keys(var.kaito_models)

  # Combined model lists as JSON for APIM policy expressions
  foundry_models_json = jsonencode(local.foundry_model_names)
  kaito_models_json   = jsonencode(local.kaito_model_names)
}

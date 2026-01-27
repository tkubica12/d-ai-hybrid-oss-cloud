locals {
  base_name        = "${replace(var.prefix, "_", "-")}-${random_string.main.result}"
  base_name_nodash = replace(local.base_name, "-", "")

  # Load model catalog from config directory
  model_catalog = yamldecode(file(var.model_catalog_path))

  # Filter to enabled KAITO models
  enabled_kaito_models = {
    for model in local.model_catalog.kaito_models :
    model.name => model
    if model.enabled
  }

  # Filter to enabled Foundry models
  enabled_foundry_models = [
    for model in local.model_catalog.foundry_models :
    {
      name       = model.name
      model_name = model.model_name
      version    = model.version
      sku_name   = model.sku_name
      capacity   = model.capacity
    }
    if model.enabled
  ]
}

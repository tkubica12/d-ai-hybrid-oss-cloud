# Common Errors and Solutions

## APIM Product-API Link 409 Conflict

### Error
```
Error: Failed to create/update resource
creating/updating Resource: PUT ...products/product-xxx/apiLinks/link-openai-api
RESPONSE 409: 409 Conflict
ERROR CODE: Conflict
"message": "Link already exists between specified Product and Api."
```

### Context
Occurs when using `azapi_resource` with type `Microsoft.ApiManagement/service/products/apiLinks@2024-06-01-preview` to associate an API with an APIM product.

### Root Cause
The `apiLinks` resource type has multiple issues:
1. Reports conflict even when resource doesn't exist
2. Import not supported (`Resource ImportState method returned no State in response`)
3. GET method returns 405, breaking Terraform refresh

### Solution
Use `azurerm_api_management_product_api` instead of azapi:

```hcl
resource "azurerm_api_management_product_api" "openai" {
  for_each = local.teams

  api_name            = local.platform.openai_api_name
  product_id          = "product-${each.value.name}"
  api_management_name = local.platform.apim_name
  resource_group_name = local.platform.resource_group_name

  depends_on = [azapi_resource.apim_product]
}
```

### Recovery Steps
If you're stuck with an orphaned `apiLinks` resource:
1. Delete via REST API: `az rest --method DELETE --uri ".../products/product-xxx/apiLinks/link-xxx?api-version=2024-06-01-preview"`
2. Or create the link using the older endpoint: `az rest --method PUT --uri ".../products/product-xxx/apis/api-name?api-version=2024-06-01-preview"`
3. Then import into Terraform using the azurerm resource type

---

## KAITO Model Version Compatibility

### Error
Model deployment fails or pod crashes with unsupported model errors.

### Context
Selecting KAITO models that aren't supported by the AKS add-on version.

### Root Cause
AKS KAITO add-on uses a specific version of KAITO (currently 0.6.0) which supports a subset of models. Newer models like `gemma-3-*` require KAITO 0.8.x.

### Solution
Check the KAITO version in AKS and select compatible models:

**KAITO 0.6.0 Supported Models:**
- falcon-7b-instruct, falcon-40b-instruct
- phi-3-mini-4k-instruct, phi-3.5-mini-instruct
- mistral-7b-instruct
- llama-2-7b-chat, llama-2-13b-chat

**KAITO 0.8.x Required For:**
- gemma-3-4b-instruct, gemma-3-27b-instruct
- Other newer models

### Verification
Check the KAITO extension version:
```bash
az k8s-extension show --name kaito --cluster-name <aks-name> --resource-group <rg> --cluster-type managedClusters --query version
```

---

## AzAPI Provider v2.8.0 - Missing Resource Identity After Read

### Error
```
Error: Missing Resource Identity After Read

  with module.ai_platform.azapi_resource.foundry_deployment["gpt-5-mini"],
  on modules\ai-platform\foundry.tf line 73, in resource "azapi_resource" "foundry_deployment":
   73: resource "azapi_resource" "foundry_deployment" {

The Terraform Provider unexpectedly returned no resource identity data after having no errors in the resource read. This is always an issue in the Terraform Provider and should be reported to the provider developers.
```

### Context
Occurs during `terraform refresh`, `plan`, or `apply` operations when using the azapi provider version 2.8.0 with resources like `Microsoft.CognitiveServices/accounts/deployments`.

### Root Cause
This is a known bug in azapi provider version 2.8.0 (GitHub issue #1023). The provider fails to return proper resource identity data after successful read operations.

### Solution
Pin the azapi provider to version 2.7.0 in your `providers.tf`:

```hcl
required_providers {
  azapi = {
    source  = "azure/azapi"
    version = "= 2.7.0"  # Pinned to 2.7.0 - v2.8.0 has bug causing "Missing Resource Identity After Read" errors
  }
}
```

### Recovery Steps
1. Update the provider version constraint in `providers.tf`
2. Run `terraform init -upgrade` to downgrade the provider
3. Run `terraform plan` or `terraform apply` - the errors should be resolved

# Common Errors and Solutions

## kubernetes_manifest Requires Cluster During Plan

### Error
```
Error: Failed to construct REST client
cannot create REST client: no client config

  with module.kaito.kubernetes_manifest.kaito_workspace["phi-4"]
```

### Context
Occurs when using `kubernetes_manifest` resource from HashiCorp's kubernetes provider to deploy CRDs (like KAITO Workspace) in the same terraform apply that creates the AKS cluster.

### Root Cause
The `kubernetes_manifest` resource **requires API access during planning time**. This is documented behavior from HashiCorp:

> "This resource requires API access during planning time. This means the cluster has to be accessible at plan time and thus cannot be created in the same apply operation."

This creates a chicken-and-egg problem: the kubernetes provider needs credentials from AKS, but AKS doesn't exist yet during plan.

### Solution
Use the **Helm provider** with `helm_release` resource instead. The Helm provider does NOT require cluster connection during plan - only during apply.

1. Create a local Helm chart for your CRDs (e.g., `/charts/kaito-models/`)
2. Use `helm_release` with the local chart path
3. Pass AKS credentials to the Helm provider

```hcl
# In module providers.tf
provider "helm" {
  kubernetes {
    host                   = var.kube_host
    cluster_ca_certificate = base64decode(var.kube_cluster_ca_certificate)
    client_certificate     = base64decode(var.kube_client_certificate)
    client_key             = base64decode(var.kube_client_key)
  }
}

# In module main.tf
resource "helm_release" "kaito_models" {
  name  = "kaito-models"
  chart = "${path.module}/../../../../charts/kaito-models"
  # ... values from var.enabled_models
}
```

### Why NOT These Alternatives
- **Two-stage apply with -target**: Requires manual intervention, not idempotent
- **kubectl provider (gavinbunney)**: Third-party provider, not HashiCorp official
- **null_resource with local-exec**: Fragile, requires kubectl installed locally

---

## APIM Policy C# Expressions in XML - Quote Escaping

### Error
```
RESPONSE 400: 400 Bad Request
ERROR CODE: ValidationError
"message": "'deployment-id' is an unexpected token. Expecting white space. Line 5, position 99."
```
Or similar XML parsing errors with "unexpected token" mentioning a string literal.

### Context
Occurs when using C# policy expressions in APIM policies that contain double quotes inside XML attributes.

### Root Cause
When a C# expression like `context.Request.MatchedParameters.GetValueOrDefault("deployment-id", "")` is placed inside an XML attribute `value="..."`, the inner double quotes break XML parsing.

### Solution
Use XML entity encoding `&quot;` for all double quotes inside C# expressions within XML attributes:

**Wrong:**
```xml
<set-variable name="model-name" value="@(context.Request.MatchedParameters.GetValueOrDefault("deployment-id", ""))" />
```

**Correct:**
```xml
<set-variable name="model-name" value="@(context.Request.MatchedParameters.GetValueOrDefault(&quot;deployment-id&quot;, &quot;&quot;))" />
```

Also escape `<` and `>` as `&lt;` and `&gt;` for generic types:
```xml
<when condition="@(context.Variables.GetValueOrDefault&lt;string&gt;(&quot;model-name&quot;) == &quot;gpt-4.1&quot;)">
```

---

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

# Common Errors and Solutions

## APIM to KAITO/vLLM Returns 404 "Not Found"

### Error
```json
{"detail": "Not Found"}
```
HTTP 404 when calling KAITO models through APIM, but direct calls to vLLM from within the cluster work.

### Context
This error has two common causes:

1. **Incorrect URL rewriting**: APIM's `context.Request.Url.Path` returns only the operation path (e.g., `chat/completions`), not the full API path. If your rewrite-uri tries to replace `/openai/v1`, it won't find it.

2. **Model name mismatch**: vLLM uses the preset name as the model ID (e.g., `mistral-7b-instruct`), but requests may send a different name (e.g., `mistral-7b`).

### Solution

**For URL rewriting:**
```xml
<!-- WRONG: context.Request.Url.Path is just "chat/completions" -->
<rewrite-uri template="@("/v1" + context.Request.Url.Path.Replace("/openai/v1", ""))" />

<!-- CORRECT: Simply prepend /v1/ to the operation path -->
<rewrite-uri template="@("/v1/" + context.Request.Url.Path)" copy-unmatched-params="true" />
```

**For model naming:** Align user-facing names with vLLM preset names in `model_catalog.yaml`:
```yaml
# Use the same name as the preset to avoid body rewriting
- name: mistral-7b-instruct   # Same as preset
  preset: mistral-7b-instruct
```

### Debugging Tips
- Check vLLM model names: `curl http://<vllm-ip>/v1/models`
- Test direct access: `kubectl run --rm -it debug --image=curlimages/curl -- curl http://<lb-ip>/v1/chat/completions ...`
- Use debug return-response in APIM to inspect `context.Request.Url.Path` vs `context.Request.OriginalUrl.Path`

---

## azapi Provider: Missing Resource Identity After Read

### Error
```
Error: Missing Resource Identity After Read

The Terraform Provider unexpectedly returned no resource identity data
after having no errors in the resource read. This is always an issue in the
Terraform Provider and should be reported to the provider developers.
```

### Context
Occurs with azapi provider v2.8.0 when reading resources that have been modified outside of Terraform or when there's API response issues. The resources are valid in Azure but the provider fails to read them.

### Solution
Remove the affected resources from state and let Terraform recreate them:

```bash
# Remove corrupted resources from state
terraform state rm 'azapi_resource.example["key"]'

# Run apply to recreate (will use existing Azure resources if they support upsert)
terraform apply
```

The APIM resources like products and subscriptions support idempotent creation, so they'll be recreated without issue. Cognitive Services accounts may need to be deleted first if they already exist.

---

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

## Azure LoadBalancer Static IP Not Assigned

### Error
```
Warning  SyncLoadBalancerFailed  service-controller  Error syncing load balancer: 
failed to ensure load balancer: ensure(default/kaito-lb-mistral-7b): 
lb(kubernetes-internal) - failed to get subnet:
vnet-hai-iwjf//subscriptions/.../subnets/aks
```

LoadBalancer service gets a random IP instead of the requested static IP specified in annotations.

### Context
Using `service.beta.kubernetes.io/azure-load-balancer-internal-subnet` annotation with the full Azure resource ID instead of just the subnet name.

### Root Cause
The annotation `azure-load-balancer-internal-subnet` expects **only the subnet name**, not the full Azure resource ID.

**Wrong:**
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "/subscriptions/.../subnets/aks"
```

**Correct:**
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "aks"
```

### Solution
1. Update Helm values to pass subnet name only (not full resource ID)
2. Use the `staticIP` field in model catalog to specify the IP per model
3. Ensure the static IP is from the correct subnet range and not already in use

**Correct LoadBalancer annotations for static internal IP:**
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "aks"
  service.beta.kubernetes.io/azure-load-balancer-ipv4: "10.10.0.200"
```

---

## Helm Provider with AKS Data Source - First Run Failure

### Error
```
Error: Failed to check installed release version
Kubernetes cluster unreachable: invalid configuration: no configuration has been provided
```

### Context
Occurs when the Helm provider is configured with a data source for AKS credentials, but AKS doesn't exist yet on the first terraform run.

### Root Cause
Terraform providers are initialized **before** any resources are evaluated. A data source used in provider configuration is evaluated at init time, not during the apply phase. If AKS doesn't exist yet, the data source fails.

### Solution
**Two-stage apply approach:**

1. On first run, create AKS without Helm deployments:
   ```bash
   terraform apply -target=module.aks_kaito
   ```

2. Then run full apply for Helm charts:
   ```bash
   terraform apply
   ```

**Provider Configuration:**
```hcl
# Root-level data source (NO depends_on - wouldn't help)
data "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${local.base_name}"
  resource_group_name = "rg-${local.base_name}"
}

provider "helm" {
  kubernetes = {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }
}
```

### Why NOT These Alternatives
- **depends_on in data source**: Doesn't help - providers are initialized before resources
- **kubeconfig file (~/.kube/config)**: Doesn't work on first run if AKS is created by same terraform
- **Module outputs in provider**: Not allowed - providers can't reference computed values

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

---

## azapi_resource APIM Policy "Missing Resource Identity After Update"

### Error
```
Error: Missing Resource Identity After Update

  with azapi_resource.apim_product_policy["team-beta"],
  on apim.tf line 121, in resource "azapi_resource" "apim_product_policy":
 121: resource "azapi_resource" "apim_product_policy" {

The Terraform Provider unexpectedly returned no resource identity data after having no errors in the resource update.
```

### Context
Occurs when using `azapi_resource` to manage APIM policies, backends, or operation policies. The azapi provider v2.x has a bug where it fails to return resource identity after updates for certain APIM child resources.

### Root Cause
The azapi provider does not properly handle the response from Azure APIM policy/backend update operations, causing state tracking failures.

### Solution
Convert the affected `azapi_resource` definitions to use the equivalent `azurerm` provider resources:

| azapi Resource Type | azurerm Replacement |
|---------------------|---------------------|
| `Microsoft.ApiManagement/service/products/policies` | `azurerm_api_management_product_policy` |
| `Microsoft.ApiManagement/service/backends` | `azurerm_api_management_backend` |
| `Microsoft.ApiManagement/service/apis/operations/policies` | `azurerm_api_management_api_operation_policy` |

**Before (azapi - problematic):**
```hcl
resource "azapi_resource" "apim_product_policy" {
  type      = "Microsoft.ApiManagement/service/products/policies@2024-06-01-preview"
  name      = "policy"
  parent_id = azapi_resource.apim_product[each.key].id
  body = {
    properties = {
      format = "xml"
      value  = local.policy_xml
    }
  }
}
```

**After (azurerm - working):**
```hcl
resource "azurerm_api_management_product_policy" "main" {
  product_id          = "product-${each.value.name}"
  api_management_name = local.platform.apim_name
  resource_group_name = local.platform.resource_group_name
  xml_content         = local.policy_xml

  depends_on = [azapi_resource.apim_product]
}
```

### Migration Steps
1. Remove the old azapi resources from state:
   ```powershell
   terraform state rm 'azapi_resource.apim_product_policy["team-alpha"]'
   ```
2. Import the existing resources into the new azurerm resource addresses:
   ```powershell
   terraform import 'azurerm_api_management_product_policy.main["team-alpha"]' "/subscriptions/.../products/product-alpha"
   ```
3. Run `terraform apply` - no changes should be needed if the configuration matches

# GitOps Applications

Commit Argo CD manifests to this directory to onboard workloads. The bootstrap application points here, so any files added will be discovered and synced automatically once Argo CD is running.

## Included applications

- `azure-service-operator.yaml` &mdash; installs Azure Service Operator v2 with workload identity enabled so that Kubernetes resources can provision Azure infrastructure.
- `envoy-gateway.yaml` &mdash; deploys Envoy Gateway into `envoy-gateway-system`.
- `cert-manager.yaml` &mdash; installs cert-manager and its CRDs via Helm to provide certificate management for dependent workloads (e.g., Azure Service Operator).

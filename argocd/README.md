# Argo CD Bootstrap

This directory contains the top-level Argo CD bootstrap manifest and supporting documents.

- `bootstrap-application.yaml` installs an app-of-apps targeting the `argocd/apps` directory in this repository.
- `apps/` holds individual Argo CD `Application` or `AppProject` definitions that the bootstrap will reconcile automatically.
	- `azure-service-operator.yaml` installs Azure Service Operator v2 via Helm and pulls runtime configuration from the `platform-bootstrap-settings` ConfigMap created during Terraform apply.
	- `envoy-gateway.yaml` deploys the Envoy Gateway Helm chart.

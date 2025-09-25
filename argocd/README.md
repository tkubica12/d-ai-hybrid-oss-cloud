# Argo CD Bootstrap

This directory contains the top-level Argo CD bootstrap manifest and supporting documents.

- `bootstrap-application.yaml` installs an app-of-apps targeting the `argocd/apps` directory in this repository.
- `apps/` holds individual Argo CD `Application` or `AppProject` definitions that the bootstrap will reconcile automatically.

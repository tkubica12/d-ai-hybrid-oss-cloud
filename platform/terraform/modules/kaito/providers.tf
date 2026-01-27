# KAITO Module
# Manages KAITO workspace deployments and LoadBalancer services for OSS models
# Uses Helm provider which does NOT require cluster connection during plan

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

# Helm provider is passed from the root module - do not configure here
# This allows proper dependency ordering

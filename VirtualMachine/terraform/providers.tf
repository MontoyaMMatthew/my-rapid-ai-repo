# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.14.0"
    }
  }

  required_version = ">= 1.9.0"
}

provider "azurerm" {
  # "none": do not try to register Azure resource providers on every plan. Registration
  # needs subscription-level rights students do not have, and it is slow. The trade is
  # that the INSTRUCTOR registers Microsoft.Network, Microsoft.Compute and
  # Microsoft.Storage once per subscription before the first student deploys:
  #   az provider register --namespace Microsoft.Network --subscription <id>
  # A fresh subscription that skipped this fails every network resource with
  # "409 MissingSubscriptionRegistration".
  resource_provider_registrations = "none"
  subscription_id                 = var.studentSubscriptionId
  features {}
}
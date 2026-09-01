terraform {
  cloud {
    organization = "flink_ccloud_terraform"

    workspaces {
      name = "cicd_flink_ccloud_terraform"
    }
  }

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "2.2.0"
    }
  }
}
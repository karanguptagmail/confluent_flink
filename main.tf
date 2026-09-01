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

locals {
  cloud  = "AWS"
  region = "us-east-2"
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

# Using an existing Confluent environment.

data "confluent_environment" "atlas-dev-v2" {
    id = var.confluent_environment_id
}

# use an existing kafka cluster

data "confluent_kafka_cluster" "atlas-dev-cluster-v2" {
    id = var.confluent_kafka_cluster_id

  environment {
    id = data.confluent_environment.atlas-dev-v2.id
  }

}

# Access the Stream Governance Essentials package to the environment.
data "confluent_schema_registry_cluster" "schema_registry_cluster" {
  environment {
    id = data.confluent_environment.atlas-dev-v2.id
  }
}


# Create a new Service Account. This will used during Kafka API key creation and Flink SQL statement submission.
resource "confluent_service_account" "flink_service_account" {
  display_name = "flink_service_account"
}

data "confluent_organization" "my_org" {}

# Assign the OrganizationAdmin role binding to the above Service Account.
# This will give the Service Account the necessary permissions to create topics, Flink statements, etc.
# In production, you may want to assign a less privileged role.
resource "confluent_role_binding" "my_org_admin_role_binding" {
  principal   = "User:${confluent_service_account.flink_service_account.id}"
  role_name   = "OrganizationAdmin"
  crn_pattern = data.confluent_organization.my_org.resource_name

  depends_on = [
    confluent_service_account.flink_service_account
  ]
}


# Create a Flink compute pool to execute a Flink SQL statement.
resource "confluent_flink_compute_pool" "flink_coveo_dev" {
  display_name = "my_compute_pool"
  cloud        = local.cloud
  region       = local.region
  max_cfu      = 5

  environment {
    id = data.confluent_environment.atlas-dev-v2.id
  }

  depends_on = [
    data.confluent_environment.atlas-dev-v2
  ]
}
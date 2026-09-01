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
  display_name = "flink_coveo_dev"
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


# Create a Flink-specific API key that will be used to submit statements.
data "confluent_flink_region" "my_flink_region" {
  cloud  = local.cloud
  region = local.region
}

resource "confluent_api_key" "my_flink_api_key" {
  display_name = "my_flink_api_key"

  owner {
    id          = confluent_service_account.flink_service_account.id
    api_version = confluent_service_account.flink_service_account.api_version
    kind        = confluent_service_account.flink_service_account.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.my_flink_region.id
    api_version = data.confluent_flink_region.my_flink_region.api_version
    kind        = data.confluent_flink_region.my_flink_region.kind

    environment {
      id = data.confluent_environment.atlas-dev-v2.id
    }
  }

  depends_on = [
    data.confluent_environment.atlas-dev-v2,
    confluent_service_account.flink_service_account
  ]
}


# Deploy a Flink SQL statement to Confluent Cloud.
resource "confluent_flink_statement" "my_flink_statement" {
  organization {
    id = data.confluent_organization.my_org.id
  }

  environment {
    id = confluent_environment.atlas-dev-v2.id
  }

  compute_pool {
    id = confluent_flink_compute_pool.flink_coveo_dev.id
  }

  principal {
    id = confluent_service_account.flink_service_account.id
  }

  # This SQL reads data from source_topic, filters it, and ingests the filtered data into sink_topic.
  statement = <<EOT
    CREATE TABLE my_sink_topic AS
    SELECT
      window_start,
      window_end,
      SUM(price) AS total_revenue,
      COUNT(*) AS cnt
    FROM
    TABLE(TUMBLE(TABLE `examples`.`marketplace`.`orders`, DESCRIPTOR($rowtime), INTERVAL '1' MINUTE))
    GROUP BY window_start, window_end;
    EOT

  properties = {
    "sql.current-catalog"  = data.confluent_environment.atlas-dev-v2.display_name
    "sql.current-database" = data.confluent_kafka_cluster.atlas-dev-cluster-v2.display_name
  }

  rest_endpoint = data.confluent_flink_region.my_flink_region.rest_endpoint

  credentials {
    key    = confluent_api_key.my_flink_api_key.id
    secret = confluent_api_key.my_flink_api_key.secret
  }

  depends_on = [
    confluent_api_key.my_flink_api_key,
    confluent_flink_compute_pool.flink_coveo_dev,
    data.confluent_kafka_cluster.atlas-dev-cluster-v2
  ]
}
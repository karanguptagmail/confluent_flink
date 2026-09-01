variable "confluent_environment_id" {
  description = "ID of an existing Confluent environment to use (e.g. env-xxxx)."
  type        = string
}

variable "confluent_kafka_cluster_id" {
  description = "ID of an existing Confluent kafka cluster to use (e.g. env-xxxx)."
  type        = string
}

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}
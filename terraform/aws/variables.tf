variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)"
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "snowflake_region" {
  description = "Snowflake region"
  type        = string
  default     = "us-west-2"
}

variable "snowflake_schema" {
  type    = string
  default = "PUBLIC"
}

variable "kube_config" {
  type    = string
  default = "~/.kube/config"
}

variable "rapidapi_key" {
  description = "API Key "
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "postgres"
}

variable "postgres_user" {
  type    = string
  default = "postgres"
}

variable "postgres_db" {
  type    = string
  default = "project_1"
}

variable "storage_class" {
  type    = string
  default = "hostpath"
}

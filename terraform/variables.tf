variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
  sensitive = true
}

variable "clone" {
  type = list(string)
}

variable "name" {
  type = list(string)
}

variable target_node {
  type = string
}

variable instance_count {
  type = number
}

variable network_bridge {
  type = list(string)
}

variable ip {
  type = list(string)
}

variable server_dns {
  type = string
}

variable domain_dns {
  type = string
}

variable "size" {
  type = list(string)
}

variable storage {
  type = string
}

variable ciuser {
  type = string
}

variable cipwd {
  type = string
}

variable ssh_key {
  type = string
}
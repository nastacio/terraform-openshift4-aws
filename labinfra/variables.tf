variable "environment_name" {
  description = "Basic name of the environment. An internal concept for this TF module."
  nullable    = false
  type        = string
}

variable "base_domain" {
  type = string

  description = <<EOF
The base DNS domain of the cluster. It must NOT contain a trailing period. Some
DNS providers will automatically add this if necessary.

Example: `openshift.example.com`.

Note: This field MUST be set manually prior to creating the cluster.
This applies only to cloud platforms.
EOF

}
variable "cert_owner" {
  description = "Email of the account owner at LetsEncrypt."
  nullable    = false
  type        = string
}
variable "registry_username" {
  description = "Mirrored registry username."
  nullable    = false
  sensitive   = true
  type        = string
}
variable "registry_password" {
  description = "Mirrored registry password."
  nullable    = false
  sensitive   = true
  type        = string
}
variable "rhsm_username" {
  description = "Red Hat subscription username."
  nullable    = false
  sensitive   = true
  type        = string
}
variable "rhel_pull_secret" {
  description = "Red Hat Image Pull secret."
  nullable    = false
  sensitive   = true
  type        = string
}
variable "rhsm_password" {
  description = "Red Hat subscription password."
  nullable    = false
  sensitive   = true
  type        = string
}
variable "ssh_public_key" {
  description = "File name containing public SSH key added to all instances created with this plan."
  nullable    = false
  type        = string
}
variable "ssh_private_key" {
  description = "File name containing private SSH key used for remote execution on instances."
  nullable    = false
  sensitive   = true
  type        = string
}
variable "route_53_zone_id" {
  description = "Zone identifier for the Route 53 instance."
  nullable    = false
  type        = string
}
variable "openshift_version" {
  type    = string
  default = "4.8.38"
}
variable "ocp_public_subnet_cidr_a" {
    description = "CIDR for the OCP Public Subnet"
    default = "10.0.16.0/20"
}

variable "ocp_private_subnet_cidr_a" {
    description = "CIDR for the OCP Private Subnet"
    default = "10.0.128.0/20"
}

variable "aws_region" {
  type        = string
  description = "The target AWS region for the cluster."
}
variable "availability_zones" {
  type        = list(string)
  description = "The availability zones in which to provision subnets."
}

variable "airgap" {
  type = bool
  default = false
}

variable "public_subnet_ids" {
  type        = list(string)
}

variable "private_subnet_ids" {
  type        = list(string)
}

variable "vpc_id" {
  type        = string
}

#
# Thanks to Terraform docs and to Hasitha Algewatta for his excellent
# article: https://medium.com/@hmalgewatta/setting-up-an-aws-ec2-instance-with-ssh-access-using-terraform-c336c812322f
#

locals {
  tags    = var.aws_extra_tags
  aws_azs = (var.aws_azs != null) ? var.aws_azs : tolist([join("", [var.aws_region, "a"]), join("", [var.aws_region, "b"]), join("", [var.aws_region, "c"])])
}


#
#
#
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}




#
# Configure the AWS Provider
#
provider "aws" {
  profile = "default"
  region  = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment_name
      Service     = "bringup-lab"
    }
  }
}


module "vpc" {
  source = "./vpc"

  cidr_blocks        = [var.machine_cidr]
  cluster_id         = var.environment_name
  region             = var.aws_region
  vpc                = var.aws_vpc
  public_subnets     = var.aws_public_subnets
  private_subnets    = var.aws_private_subnets
  publish_strategy   = var.aws_publish_strategy
  airgapped          = var.airgapped
  availability_zones = local.aws_azs

  tags = local.tags
}


#
#
#
module "labinfra" {
  source = "./labinfra"

  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  availability_zones = local.aws_azs
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids

  environment_name  = var.environment_name
  base_domain       = var.base_domain
  cert_owner        = var.cert_owner
  registry_username = var.registry_username
  registry_password = var.registry_password
  rhsm_username     = var.rhsm_username
  rhsm_password     = var.rhsm_password
  rhel_pull_secret  = var.rhel_pull_secret
  ssh_public_key    = var.ssh_public_key
  ssh_private_key   = var.ssh_private_key
  route_53_zone_id  = var.route_53_zone_id

  depends_on = [ module.vpc.aws_lb_api_external_dns_name ]
}


#
#
#
# module "openshift" {
#   source = "git::https://github.com/nastacio/terraform-openshift4-aws"

#   cluster_name          = var.environment_name
#   base_domain           = var.base_domain
#   openshift_pull_secret = var.rhel_pull_secret
#   openshift_version     = var.openshift_version

#   aws_extra_tags = {
#     "owner" = "sdlc-cd"
#     "env"   = var.environment_name
#   }
#   aws_vpc              = module.vpc.vpc_id
#   aws_region           = var.aws_region
#   aws_azs              = var.aws_azs
#   aws_private_subnets  = module.vpc.private_subnet_ids
#   aws_public_subnets   = module.vpc.public_subnet_ids
#   aws_publish_strategy = var.aws_publish_strategy

  # airgapped = {
  #   "enabled"    = var.airgap
  #   "repository" = "https://${local.bastion_hostname}:5555"
  # }
# }

# output "infra_id" {
#   value = module.openshift.infraID
# }

# output "kubeadmin" {
#   value = module.openshift.kubeadmin
# }

# output "console_url" {
#   value = module.openshift.consoleURL
# }

# output "api_url" {
#   value = module.openshift.apiURL
# }

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "registry_url" {
  value = module.labinfra.registry_url
}

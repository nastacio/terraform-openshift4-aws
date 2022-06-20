# output "aws_internet_gateway_id" {
#   value = aws_internet_gateway.vpc_gw.id
# }

output "registry_url" {
  value = "https://${aws_route53_record.bastion-dns.name}:5555"
}

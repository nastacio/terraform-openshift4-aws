terraform {
  required_version = ">= 0.12"
}

variable "machine_cidr" {
  type = string

  description = <<EOF
The IP address space from which to assign machine IPs.
Default "10.0.0.0/16"
EOF
  default = "10.0.0.0/16"
}

variable "use_ipv4" {
  type    = bool
  default = true
  description = "not implemented"
}

variable "use_ipv6" {
  type    = bool
  default = false
  description = "not implemented"
}

variable "airgapped" {
  type = map(string)
  default = {
    enabled  = false
    repository = ""
  }
}

variable "proxy_config" {
  type = map(string)
  description = "Not implemented"
  default = {
    enabled    = false
    httpProxy  = "http://user:password@ip:port"
    httpsProxy = "http://user:password@ip:port"
    noProxy    = "ip1,ip2,ip3,.example.com,cidr/mask"
  }
}

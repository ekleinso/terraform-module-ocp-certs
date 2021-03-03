// OCP cluster name
variable "cluster_id" {
  type = string
}

// OCP cluster config directory
variable "cluster_dir" {
  type = string
}

// The OCP API VIP
variable "api_vip" {
  type = string
}

// The OCP Ingress VIP
variable "ingress_vip" {
  type = string
}

// Base DNS domain name
variable "dns_domain" {
  type = string
}

variable "ca_cert_chain" {
  default = ""
  description = "Location of the user provided root CA certificate chain in the repo"
}

variable "ca_cert_pem" {
  default = "certs/root.ca.crt"
  description = "Location of the user provided root CA certificate in the repo"
}

variable "ca_private_key_pem" {
  default = "certs/root.ca.key"
  description = "Location of the user provided root CA certificate key in the repo"
}

variable "private_key_algorithm" {
  description = "The name of the algorithm to use for private keys. Must be one of: RSA or ECDSA."
  default     = "RSA"
}

variable "private_key_ecdsa_curve" {
  description = "The name of the elliptic curve to use. Should only be used if var.private_key_algorithm is ECDSA. Must be one of P224, P256, P384 or P521."
  default     = "P256"
}

variable "private_key_rsa_bits" {
  description = "The size of the generated RSA key in bits. Should only be used if var.private_key_algorithm is RSA."
  default     = "4096"
}

variable "allowed_uses" {
  description = "List of keywords from RFC5280 describing a use that is permitted for the issued certificate. For more info and the list of keywords, see https://www.terraform.io/docs/providers/tls/r/self_signed_cert.html#allowed_uses."
  type        = list

  default = [
    "key_encipherment",
    "digital_signature",
  ]
}

variable "validity_period_hours" {
  description = "The number of hours after initial issuing that the certificate will become invalid."
  default = "17520"
}


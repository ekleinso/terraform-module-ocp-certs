locals {
  certificates_path = var.cluster_dir == "" ? format("%s/installer/%s/certificates", path.root, var.cluster_id) : format("%s/certificates", var.cluster_dir) 
  kubeconfig = var.cluster_dir == "" ? format("%s/installer/%s/auth/kubeconfig", path.root, var.cluster_id) : format("%s/auth/kubeconfig", var.cluster_dir)
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A TLS CERTIFICATE SIGNED USING THE CA CERTIFICATE
# ---------------------------------------------------------------------------------------------------------------------

resource "tls_private_key" "openshift" {
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

#
resource "local_file" "openshift_key" {
    content  = tls_private_key.openshift.private_key_pem
    filename = format("%s/openshift.key.pem", local.certificates_path)
    file_permission = 644
}

resource "tls_cert_request" "openshift" {
  key_algorithm   = tls_private_key.openshift.algorithm
  private_key_pem = tls_private_key.openshift.private_key_pem

  dns_names    = ["api.${var.cluster_id}.${var.dns_domain}", "*.apps.${var.cluster_id}.${var.dns_domain}"]
  ip_addresses = [var.api_vip, var.ingress_vip]

  subject {
    common_name  = "${var.cluster_id}.${var.dns_domain}"
    organization = var.dns_domain
  }
}

resource "tls_locally_signed_cert" "openshift" {
  cert_request_pem = tls_cert_request.openshift.cert_request_pem

  ca_key_algorithm   = var.private_key_algorithm
  ca_private_key_pem = file("${path.root}/${var.ca_private_key_pem}")
  ca_cert_pem        = file("${path.root}/${var.ca_cert_pem}")

  validity_period_hours = var.validity_period_hours
  allowed_uses          = var.allowed_uses

}

#
resource "local_file" "openshift_crt" {
    content  = tls_locally_signed_cert.openshift.cert_pem
    filename = format("%s/openshift.crt.pem", local.certificates_path)
    file_permission = 644
}

resource "null_resource" "ocp_cert" {
  provisioner "local-exec" {
    command = <<EOF
set -ex

../binaries/oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"user-ca-bundle"}}}'
../binaries/oc --namespace openshift-ingress create secret tls custom-cert --cert=openshift.crt.pem --key=openshift.key.pem
../binaries/oc patch --type=merge --namespace openshift-ingress-operator ingresscontrollers/default --patch '{"spec":{"defaultCertificate":{"name":"custom-cert"}}}'
EOF

    environment = {
      KUBECONFIG  = local.kubeconfig
    }

    working_dir = local.certificates_path
  }

  depends_on = [
    local_file.openshift_crt,
    local_file.openshift_key
  ]
}


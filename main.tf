locals {
  certificates_path = var.cluster_dir == "" ? format("%s/installer/%s/certificates", path.root, var.cluster_id) : format("%s/certificates", var.cluster_dir) 
  kubeconfig = var.cluster_dir == "" ? format("%s/installer/%s/auth/kubeconfig", path.root, var.cluster_id) : format("%s/auth/kubeconfig", var.cluster_dir)
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A TLS CERTIFICATE SIGNED USING THE CA CERTIFICATE
# ---------------------------------------------------------------------------------------------------------------------

resource "tls_private_key" "openshift_app" {
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

#
resource "local_file" "openshift_app_key" {
    content  = tls_private_key.openshift_app.private_key_pem
    filename = format("%s/openshift-app.key.pem", local.certificates_path)
    file_permission = 644
}

resource "tls_cert_request" "openshift_app" {
  key_algorithm   = tls_private_key.openshift_app.algorithm
  private_key_pem = tls_private_key.openshift_app.private_key_pem

  dns_names    = ["*.apps.${var.cluster_id}.${var.dns_domain}"]
  ip_addresses = [var.ingress_vip]

  subject {
    common_name  = "${var.cluster_id}.${var.dns_domain}"
    organization = var.dns_domain
  }
}

resource "tls_locally_signed_cert" "openshift_app" {
  cert_request_pem = tls_cert_request.openshift_app.cert_request_pem

  ca_key_algorithm   = var.private_key_algorithm
  ca_private_key_pem = file("${path.root}/${var.ca_private_key_pem}")
  ca_cert_pem        = file("${path.root}/${var.ca_cert_pem}")

  validity_period_hours = var.validity_period_hours
  allowed_uses          = var.allowed_uses

}

#
resource "local_file" "openshift_app_crt" {
    content  = tls_locally_signed_cert.openshift_app.cert_pem
    filename = format("%s/openshift-app.crt.pem", local.certificates_path)
    file_permission = 644
}

resource "tls_private_key" "openshift_api" {
  algorithm   = var.private_key_algorithm
  ecdsa_curve = var.private_key_ecdsa_curve
  rsa_bits    = var.private_key_rsa_bits
}

#
resource "local_file" "openshift_api_key" {
    content  = tls_private_key.openshift_api.private_key_pem
    filename = format("%s/openshift-api.key.pem", local.certificates_path)
    file_permission = 644
}

resource "tls_cert_request" "openshift_api" {
  key_algorithm   = tls_private_key.openshift_api.algorithm
  private_key_pem = tls_private_key.openshift_api.private_key_pem

  dns_names    = ["api.${var.cluster_id}.${var.dns_domain}", "api-int.${var.cluster_id}.${var.dns_domain}"]
  ip_addresses = [var.api_vip]

  subject {
    common_name  = "${var.cluster_id}.${var.dns_domain}"
    organization = var.dns_domain
  }
}

resource "tls_locally_signed_cert" "openshift_api" {
  cert_request_pem = tls_cert_request.openshift_api.cert_request_pem

  ca_key_algorithm   = var.private_key_algorithm
  ca_private_key_pem = file("${path.root}/${var.ca_private_key_pem}")
  ca_cert_pem        = file("${path.root}/${var.ca_cert_pem}")

  validity_period_hours = var.validity_period_hours
  allowed_uses          = var.allowed_uses

}

#
resource "local_file" "openshift_api_crt" {
    content  = tls_locally_signed_cert.openshift_api.cert_pem
    filename = format("%s/openshift-api.crt.pem", local.certificates_path)
    file_permission = 644
}

resource "null_resource" "ocp_cert" {
  provisioner "local-exec" {
    command = <<EOF
set -ex

../binaries/oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"user-ca-bundle"}}}'
../binaries/oc --namespace openshift-ingress create secret tls custom-cert --cert=${local_file.openshift_app_crt.filename} --key=${local_file.openshift_app_key.filename}
../binaries/oc patch --type=merge --namespace openshift-ingress-operator ingresscontrollers/default --patch '{"spec":{"defaultCertificate":{"name":"custom-cert"}}}'
EOF

    environment = {
      KUBECONFIG  = local.kubeconfig
    }

    working_dir = local.certificates_path
  }

  depends_on = [
    local_file.openshift_api_crt,
    local_file.openshift_api_key,
    local_file.openshift_app_crt,
    local_file.openshift_app_key
  ]
}


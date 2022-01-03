locals {
  gcp_location_parts = split("-", var.gcp_location)
  gcp_region         = "${local.gcp_location_parts[0]}-${local.gcp_location_parts[1]}"
}

resource "kubernetes_namespace" "airbyte" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "plural"
      "app.plural.sh/name" = "airbyte"
    }
  }
}

resource "google_storage_bucket" "airbyte_bucket" {
  name = var.airbyte_bucket
  project = var.project_id
  force_destroy = true
}

resource "google_storage_bucket_iam_member" "airbyte" {
  bucket = google_storage_bucket.airbyte_bucket.name
  role = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.airbyte.email}"

  depends_on = [
    google_storage_bucket.airbyte_bucket,
    google_service_account.airbyte
  ]
}

resource "google_service_account" "airbyte" {
  account_id   = "${var.cluster_name}-airbyte"
  display_name = "Plural Airbyte"
}

resource "google_service_account_key" "airbyte_key" {
  service_account_id = google_service_account.airbyte.name
}

resource "kubernetes_secret" "google-application-credentials" {
  metadata {
    name = "airbyte-gcp-credentials"
    namespace = kubernetes_namespace.airbyte.metadata.name
  }

  data = {
    "credentials.json" = base64decode(google_service_account_key.airbyte_key.private_key)
  }
}
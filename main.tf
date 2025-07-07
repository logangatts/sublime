# Sublime Platform Google Workspace Deployment
# Author: Logan Gatts
# Date: 06/05/2025

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    time = {
      source = "hashicorp/time"
      version = "0.13.1"
    }
  }
  required_version = ">= 1.3.0"
}

provider "google" {
  credentials = null #running in gcp cloud shell so it'll use those
}

#enable cloud resource manager and iam APIs for the current cloud console context - required to complete the rest of the tf config file
data "external" "enable_tf_apis" {
  program = ["bash", "-c", <<-EOT
    COMMAND=$(gcloud services enable cloudresourcemanager.googleapis.com iam.googleapis.com)
    jq -n --arg command "$COMMAND"
  EOT
  ]
}

# Make a random project ID and org ID (needed for project creation overlap prevention)
data "external" "org_and_project_id" {
  program = ["bash", "-c", <<-EOT
    ORG_ID=$(gcloud organizations list --format='value(ID)' | head -n1)
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
    RAND=$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)
    jq -n --arg current "$CURRENT_PROJECT" --arg org "$ORG_ID" --arg pid "sublime-project-$RAND" '{org_id: $org, project_id: $pid}'
  EOT
  ]
}

# variables
locals {
  org_id     = data.external.org_and_project_id.result.org_id
  project_id = data.external.org_and_project_id.result.project_id
}

variable "oauth_email" {
 description = "Support Email Address Used When Creating oAuth Branding"
 type        = string
 #default     = "logan@deltaspecter.com"
 default     = data.external.current_user.result["email"]
}
#---------------------- Create Project ------------------------------------------
resource "google_project" "sublime_project" {
  name       = "sublime-platform"
  project_id = local.project_id
  org_id     = local.org_id
}
#---------------------- Enable APIs ----------------------------------------------
# Enable Admin SDK API
resource "google_project_service" "admin_sdk" {
  project             = google_project.sublime_project.project_id
  service             = "admin.googleapis.com"
  disable_on_destroy  = false
}

# Enable Gmail API
resource "google_project_service" "gmail" {
  project             = google_project.sublime_project.project_id
  service             = "gmail.googleapis.com"
  disable_on_destroy  = false
}

# Enable Cloud Pub/sub API
resource "google_project_service" "cloud_pubsub" {
  project             = google_project.sublime_project.project_id
  service             = "pubsub.googleapis.com"
  disable_on_destroy  = false
}

# Enable Alert Center API
resource "google_project_service" "alert_center" {
  project             = google_project.sublime_project.project_id
  service             = "alertcenter.googleapis.com"
  disable_on_destroy  = false
}

#IAM API used for service account creation/permissions
resource "google_project_service" "iam" {
  project             = google_project.sublime_project.project_id
  service             = "iam.googleapis.com"
  disable_on_destroy  = false
}

#Have to create branding to do the oAuth consent screen stuff....
#First enable IAP API
resource "google_project_service" "iap" {
  project             = google_project.sublime_project.project_id
  service             = "iap.googleapis.com"
  disable_on_destroy  = false
}

#---------------------Intentional Sleep due to GCP limitations--------------------
#required sleep because GCP is a POS... https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/google_project_service#mitigation---adding-sleeps
resource "time_sleep" "wait_20_seconds" {
  depends_on = [google_project_service.iap]
  create_duration = "20s"
}
#-------------------------------------------------------------------------------
#setup the branding (steps 17-22)
resource "google_iap_brand" "project_brand" {
  support_email     = var.oauth_email
  application_title = "Sublime Platform"
  project             = google_project.sublime_project.project_id
  depends_on = [time_sleep.wait_20_seconds]
}

#---------------------- Create Service Account----------------------------------
#create a service account
resource "google_service_account" "service_account" {
  account_id   = "sublime-service-account"
  display_name = "Sublime Service Account"
  project      = google_project.sublime_project.project_id
}

#bind it to the needed permissions
resource "google_project_iam_member" "sa_role_bind" {
  project      = google_project.sublime_project.project_id
  role         = "roles/pubsub.admin"
  member       = "serviceAccount:${google_service_account.service_account.email}"
  #format("%s%s%s%s%s","serviceAccount:sublime-service-account@",google_project.sublime_project.name, "-", local.org_id,".iam.gserviceaccount.com")
  
}

#create the SA key 
resource "google_service_account_key" "sa_key" {
  service_account_id = google_service_account.service_account.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

#---------------------- Outputs----------------------------------
output "sa_key" {
  value       = base64decode(google_service_account_key.sa_key.private_key)
  description = "Newly Created Service Account JSON key to be uploaded to Sublime"
  sensitive = true
}


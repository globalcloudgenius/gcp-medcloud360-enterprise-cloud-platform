# Shared by every stage. API calls are billed and quota-checked against the bootstrap
# project so org-level resources (org policies, budgets, SCC, VPC-SC) work consistently.
provider "google" {
  region                = var.region
  user_project_override = true
  billing_project       = var.projects.bootstrap

  default_labels = {
    app        = "medcloud360"
    managed-by = "terraform"
  }
}

provider "google-beta" {
  region                = var.region
  user_project_override = true
  billing_project       = var.projects.bootstrap

  default_labels = {
    app        = "medcloud360"
    managed-by = "terraform"
  }
}

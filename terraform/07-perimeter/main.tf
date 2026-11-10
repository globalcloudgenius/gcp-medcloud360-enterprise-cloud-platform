# =============================================================================
# Stage 07 — VPC Service Controls data perimeter around the PHI projects
#  * Protects mc360-prj-prod-app + mc360-prj-prod-data
#  * Rollout: dry run (vpcsc_dry_run = true) -> review violations -> enforce
#  * Ingress: CI identities and platform admins (Terraform, demos) — by identity
#  * Egress: portal may READ the security data lake in observability, nothing else
#  * The Access Context Manager API is not restricted, so this stage can always be
#    re-applied from outside the perimeter — that is also the rollback path.
# =============================================================================

data "google_project" "protected" {
  for_each   = toset([var.projects.prod_app, var.projects.prod_data])
  project_id = each.value
}

data "google_project" "obs" {
  project_id = var.projects.observability
}

locals {
  policy_id = var.access_policy_id != "" ? var.access_policy_id : google_access_context_manager_access_policy.org[0].name
  policy    = "accessPolicies/${local.policy_id}"

  resources = [for p in data.google_project.protected : "projects/${p.number}"]

  restricted_services = [
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudkms.googleapis.com",
    "dlp.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ]

  boot = data.terraform_remote_state.bootstrap.outputs
  sa   = data.terraform_remote_state.security.outputs.service_accounts

  trusted_identities = concat(
    [
      "serviceAccount:${local.boot.plan_service_account}",
      "serviceAccount:${local.boot.apply_service_account}",
      "serviceAccount:${local.boot.app_deploy_service_account}",
      "serviceAccount:${local.sa["invoker"]}", # Cloud Scheduler -> Cloud Run jobs API
    ],
    var.admin_members,
  )
}

locals {
  ingress = [
    {
      title      = "ci-and-admins"
      identities = local.trusted_identities
      source     = { access_level = "*", resource = null }
      service    = "*"
    },
    {
      # HL7 gateway VMs live in prod-app but their NICs are on the Shared VPC network owned by
      # mc360-prj-network (outside the perimeter): admit that network for the VM identity only.
      title      = "hl7-vms-on-shared-vpc"
      identities = ["serviceAccount:${local.sa["hl7-gw"]}"]
      source     = { access_level = null, resource = "//compute.googleapis.com/projects/${var.projects.network}/global/networks/mc360-vpc-prod" }
      service    = "*"
    },
    {
      # scc-router runs in mc360-prj-observability and pulls its image from prod-app's registry.
      title      = "observability-pulls-images"
      identities = ["serviceAccount:service-${data.google_project.obs.number}@serverless-robot-prod.iam.gserviceaccount.com"]
      source     = { access_level = null, resource = "projects/${data.google_project.obs.number}" }
      service    = "artifactregistry.googleapis.com"
    },
  ]
}

resource "google_access_context_manager_access_policy" "org" {
  count  = var.access_policy_id == "" ? 1 : 0
  parent = "organizations/${var.org_id}"
  title  = "mc360-org-policy"
}

resource "google_access_context_manager_service_perimeter" "phi" {
  parent         = local.policy
  name           = "${local.policy}/servicePerimeters/mc360_phi"
  title          = "mc360_phi"
  description    = "PHI data perimeter: prod-app + prod-data. Valid credentials alone cannot move data in or out."
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  use_explicit_dry_run_spec = true

  # Dry-run configuration: always present, logs what WOULD be blocked.
  spec {
    resources           = local.resources
    restricted_services = local.restricted_services

    dynamic "ingress_policies" {
      for_each = local.ingress
      content {
        title = ingress_policies.value.title
        ingress_from {
          identities = ingress_policies.value.identities
          sources {
            access_level = ingress_policies.value.source.access_level
            resource     = ingress_policies.value.source.resource
          }
        }
        ingress_to {
          resources = ["*"]
          operations {
            service_name = ingress_policies.value.service
            dynamic "method_selectors" {
              for_each = ingress_policies.value.service == "*" ? [] : [1]
              content {
                method = "*"
              }
            }
          }
        }
      }
    }

    egress_policies {
      title = "portal-reads-security-data-lake"
      egress_from {
        identities = ["serviceAccount:${local.sa["portal"]}"]
      }
      egress_to {
        resources = ["projects/${data.google_project.obs.number}"]
        operations {
          service_name = "bigquery.googleapis.com"
          method_selectors {
            method = "*"
          }
        }
      }
    }
  }

  # Enforced configuration: populated only when vpcsc_dry_run = false.
  dynamic "status" {
    for_each = var.vpcsc_dry_run ? [] : [1]
    content {
      resources           = local.resources
      restricted_services = local.restricted_services

      dynamic "ingress_policies" {
        for_each = local.ingress
        content {
          title = ingress_policies.value.title
          ingress_from {
            identities = ingress_policies.value.identities
            sources {
              access_level = ingress_policies.value.source.access_level
              resource     = ingress_policies.value.source.resource
            }
          }
          ingress_to {
            resources = ["*"]
            operations {
              service_name = ingress_policies.value.service
              dynamic "method_selectors" {
                for_each = ingress_policies.value.service == "*" ? [] : [1]
                content {
                  method = "*"
                }
              }
            }
          }
        }
      }

      egress_policies {
        title = "portal-reads-security-data-lake"
        egress_from {
          identities = ["serviceAccount:${local.sa["portal"]}"]
        }
        egress_to {
          resources = ["projects/${data.google_project.obs.number}"]
          operations {
            service_name = "bigquery.googleapis.com"
            method_selectors {
              method = "*"
            }
          }
        }
      }
    }
  }
}

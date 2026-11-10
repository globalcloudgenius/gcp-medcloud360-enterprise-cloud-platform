# =============================================================================
# Stage 05 — Compute (IaaS) in mc360-prj-prod-app on the shared prod subnet
#  Only what a managed service cannot do runs on VMs:
#  * HL7 v2 MLLP/TLS gateway — raw TCP 2575, persistent connections (Cloud Run is HTTP only)
#    Regional MIG over 3 zones, autoscaling + autohealing, internal passthrough TCP LB
#  * Hardened: Shielded VM, CMEK disks, no public IP, OS Login, IAP-only SSH, secure tags
#  * VM Manager: weekly zone-by-zone patching with drain/verify hooks, OS policies,
#    OS inventory + vulnerability reports, daily snapshots
#  * Windows legacy billing VM: coded, off (needs a paid billing account)
# =============================================================================

locals {
  project   = var.projects.prod_app
  net       = data.terraform_remote_state.network.outputs
  sec       = data.terraform_remote_state.security.outputs
  dat       = data.terraform_remote_state.data.outputs
  hl7       = var.enable_hl7_gateway ? 1 : 0
  zones     = ["${var.region}-a", "${var.region}-b", "${var.region}-c"]
  hl7_ip    = "10.42.0.10"
  hl7_sa    = local.sec.service_accounts["hl7-gw"]
  subnet    = local.net.subnets["prod-app-usc1"].self_link
  patch_lbl = { patch-group = "linux-prod" }
}

# --- VM Manager prerequisites (project metadata) -----------------------------------------
resource "google_compute_project_metadata_item" "meta" {
  for_each = {
    enable-osconfig         = "TRUE"
    enable-guest-attributes = "TRUE"
    enable-oslogin          = "TRUE"
  }

  project = local.project
  key     = each.key
  value   = each.value
}

resource "google_project_iam_member" "hl7_runtime" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter"])

  project = local.project
  role    = each.value
  member  = "serviceAccount:${local.hl7_sa}"
}

# --- Snapshot schedule (daily, 7 days, kept in-region) --------------------------------------
resource "google_compute_resource_policy" "daily_snapshot" {
  project = local.project
  name    = "mc360-daily-snapshot"
  region  = var.region

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "08:00"
      }
    }
    retention_policy {
      max_retention_days    = 7
      on_source_disk_delete = "APPLY_RETENTION_POLICY"
    }
    snapshot_properties {
      storage_locations = [var.region]
      labels            = { app = "medcloud360" }
    }
  }
}

# --- HL7 gateway instance template ----------------------------------------------------------
resource "google_compute_region_instance_template" "hl7" {
  count = local.hl7

  project      = local.project
  region       = var.region
  name_prefix  = "hl7-gw-"
  machine_type = "e2-small"
  description  = "HL7 MLLP/TLS gateway (Debian 12, hardened)"

  labels = merge(local.patch_lbl, { role = "hl7-gateway", data-class = "phi" })

  disk {
    source_image      = "debian-cloud/debian-12"
    disk_type         = "pd-balanced"
    disk_size_gb      = 20
    boot              = true
    auto_delete       = true
    resource_policies = [google_compute_resource_policy.daily_snapshot.id]

    disk_encryption_key {
      kms_key_self_link = local.sec.kms_keys["compute"]
    }
  }

  network_interface {
    subnetwork = local.subnet
    # no access_config: no public IP (also blocked by org policy)
  }

  service_account {
    email  = local.hl7_sa
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  resource_manager_tags = {
    (local.net.fw_tag_key) = local.net.fw_tag_values["hl7-gw"]
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    mllp-gateway-py        = file("${path.module}/../../app/hl7-gateway/mllp_gateway.py")
    startup-script = templatefile("${path.module}/../../app/hl7-gateway/startup.sh.tftpl", {
      project = local.project
      topic   = local.dat.topics["hl7-adt"]
    })
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_compute_project_metadata_item.meta]
}

resource "google_compute_health_check" "hl7" {
  count = local.hl7

  project             = local.project
  name                = "hl7-gw-tcp-2575"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = 2575
  }

  log_config {
    enable = true
  }
}

resource "google_compute_region_instance_group_manager" "hl7" {
  count = local.hl7

  project                          = local.project
  name                             = "hl7-gw-mig"
  region                           = var.region
  base_instance_name               = "hl7-gw"
  distribution_policy_zones        = local.zones
  distribution_policy_target_shape = "EVEN"

  version {
    instance_template = google_compute_region_instance_template.hl7[0].self_link
  }

  named_port {
    name = "mllp"
    port = 2575
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.hl7[0].id
    initial_delay_sec = 300
  }

  # Immutable rollouts: a new template (e.g. a rebuilt, patched image) replaces VMs
  # zone by zone with surge and no capacity loss.
  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "REPLACE"
    most_disruptive_allowed_action = "REPLACE"
    max_surge_fixed                = 3
    max_unavailable_fixed          = 0
    replacement_method             = "SUBSTITUTE"
  }
}

resource "google_compute_region_autoscaler" "hl7" {
  count = local.hl7

  project = local.project
  name    = "hl7-gw-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.hl7[0].id

  autoscaling_policy {
    min_replicas    = 2
    max_replicas    = 4
    cooldown_period = 120

    cpu_utilization {
      target = 0.6
    }
  }
}

# --- Internal passthrough TCP load balancer (Layer 4) -----------------------------------------
resource "google_compute_address" "hl7" {
  count = local.hl7

  project      = local.project
  name         = "hl7-gw-ilb"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = local.subnet
  address      = local.hl7_ip
}

resource "google_compute_region_backend_service" "hl7" {
  count = local.hl7

  project                         = local.project
  name                            = "hl7-gw-backend"
  region                          = var.region
  protocol                        = "TCP"
  load_balancing_scheme           = "INTERNAL"
  health_checks                   = [google_compute_health_check.hl7[0].id]
  session_affinity                = "CLIENT_IP"
  connection_draining_timeout_sec = 30

  backend {
    group          = google_compute_region_instance_group_manager.hl7[0].instance_group
    balancing_mode = "CONNECTION"
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_forwarding_rule" "hl7" {
  count = local.hl7

  project               = local.project
  name                  = "hl7-gw-ilb"
  region                = var.region
  load_balancing_scheme = "INTERNAL"
  ip_protocol           = "TCP"
  ports                 = ["2575"]
  ip_address            = google_compute_address.hl7[0].address
  subnetwork            = local.subnet
  backend_service       = google_compute_region_backend_service.hl7[0].id
  allow_global_access   = true
}

resource "google_dns_record_set" "hl7" {
  count = local.hl7

  project      = var.projects.network
  managed_zone = local.net.internal_dns_zone
  name         = "hl7.mc360.internal."
  type         = "A"
  ttl          = 300
  rrdatas      = [local.hl7_ip]
}

# --- VM Manager: patching, OS policy, inventory -------------------------------------------------
resource "google_os_config_patch_deployment" "linux_weekly" {
  project             = local.project
  patch_deployment_id = "mc360-linux-weekly"
  description         = "Weekly Debian patching, one VM at a time per zone, drain before / verify after"

  instance_filter {
    group_labels {
      labels = local.patch_lbl
    }
  }

  patch_config {
    mig_instances_allowed = true
    reboot_config         = "DEFAULT"

    apt {
      type = "DIST"
    }

    pre_step {
      linux_exec_step_config {
        local_path = "/opt/mc360/pre-patch.sh"
      }
    }

    post_step {
      linux_exec_step_config {
        local_path = "/opt/mc360/post-patch.sh"
      }
    }
  }

  duration = "3600s"

  recurring_schedule {
    time_zone {
      id = "America/Phoenix"
    }
    time_of_day {
      hours   = 2
      minutes = 0
    }
    weekly {
      day_of_week = "SUNDAY"
    }
  }

  rollout {
    mode = "ZONE_BY_ZONE"
    disruption_budget {
      fixed = 1
    }
  }
}

# OS policy assignments are zonal: one per zone of the MIG.
resource "google_os_config_os_policy_assignment" "baseline" {
  for_each = toset(local.zones)

  project     = local.project
  location    = each.value
  name        = "mc360-linux-baseline-${substr(each.value, -1, 1)}"
  description = "Keep unattended security upgrades installed on every PHI Linux VM"

  instance_filter {
    all = false
    inclusion_labels {
      labels = local.patch_lbl
    }
    inventories {
      os_short_name = "debian"
    }
  }

  os_policies {
    id   = "unattended-upgrades"
    mode = "ENFORCEMENT"

    resource_groups {
      resources {
        id = "unattended-upgrades-pkg"
        pkg {
          desired_state = "INSTALLED"
          apt {
            name = "unattended-upgrades"
          }
        }
      }
    }
  }

  rollout {
    min_wait_duration = "60s"
    disruption_budget {
      percent = 50
    }
  }
}

# --- Windows legacy billing app (coded, off: Windows images are not allowed on free trial) -----
resource "google_compute_instance" "windows_billing" {
  count = var.enable_windows ? 1 : 0

  project      = local.project
  name         = "win-billing-01"
  zone         = local.zones[0]
  machine_type = "e2-medium"
  labels       = { patch-group = "windows-prod", role = "legacy-billing", data-class = "phi" }

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2022"
      size  = 50
    }
    kms_key_self_link = local.sec.kms_keys["compute"]
  }

  network_interface {
    subnetwork = local.subnet
  }

  service_account {
    email  = local.hl7_sa
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  resource_policies = [google_compute_resource_policy.daily_snapshot.id]
}

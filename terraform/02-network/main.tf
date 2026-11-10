# =============================================================================
# Stage 02 — Hub-and-spoke network (host project mc360-prj-network)
#  * 4 VPCs: hub + security (NCC center group), prod + nonprod (edge group)
#  * NCC STAR topology: edge spokes can reach the center, never each other
#  * Shared VPC: prod-app/prod-data on prod subnets, dev/test on nonprod subnets
#  * Subnet-level networkUser, Cloud NAT (patch downloads only), flow logs
#  * Private Google Access: restricted.googleapis.com in prod, private.* in nonprod
#  * Cloud DNS private zone mc360.internal on all 4 VPCs
#  * Global network firewall policies with secure tags (default deny, logged)
# =============================================================================

data "google_project" "p" {
  for_each   = var.projects
  project_id = each.value
}

locals {
  host = var.projects.network

  vpcs = {
    hub      = { cidr = "10.40.0.0/16", group = "center", nat = false, description = "Shared services: DNS, PSC, hybrid VPN" }
    security = { cidr = "10.43.0.0/16", group = "center", nat = false, description = "Security tooling and admin access" }
    prod     = { cidr = "10.42.0.0/16", group = "edge", nat = true, description = "Production workloads (PHI)" }
    nonprod  = { cidr = "10.41.0.0/16", group = "edge", nat = true, description = "Development and test" }
  }

  subnets = {
    hub-shared-usc1   = { vpc = "hub", region = var.region, cidr = "10.40.0.0/24" }
    sec-tools-usc1    = { vpc = "security", region = var.region, cidr = "10.43.0.0/24" }
    prod-app-usc1     = { vpc = "prod", region = var.region, cidr = "10.42.0.0/22" }
    prod-app-use4     = { vpc = "prod", region = var.dr_region, cidr = "10.42.8.0/22" }
    nonprod-dev-usc1  = { vpc = "nonprod", region = var.region, cidr = "10.41.0.0/22" }
    nonprod-test-usc1 = { vpc = "nonprod", region = var.region, cidr = "10.41.4.0/22" }
  }

  # Which service projects may use which subnets.
  subnet_users = {
    prod-app-usc1     = ["prod_app", "prod_data"]
    prod-app-use4     = ["prod_app"]
    nonprod-dev-usc1  = ["dev"]
    nonprod-test-usc1 = ["test"]
  }

  service_projects = ["prod_app", "prod_data", "dev", "test"]

  # Google identities that attach resources to a Shared VPC subnet on behalf of a service project.
  subnet_members = {
    for pair in flatten([
      for subnet, keys in local.subnet_users : [
        for k in keys : [
          { key = "${subnet}|${k}|apis", subnet = subnet, member = "serviceAccount:${data.google_project.p[k].number}@cloudservices.gserviceaccount.com" },
          { key = "${subnet}|${k}|run", subnet = subnet, member = "serviceAccount:service-${data.google_project.p[k].number}@serverless-robot-prod.iam.gserviceaccount.com" },
        ]
      ]
    ]) : pair.key => pair
  }

  health_check_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  iap_range           = ["35.235.240.0/20"]
}

# --- VPCs and subnets -----------------------------------------------------------
resource "google_compute_network" "vpc" {
  for_each = local.vpcs

  project                         = local.host
  name                            = "mc360-vpc-${each.key}"
  description                     = each.value.description
  auto_create_subnetworks         = false
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = !each.value.nat
}

resource "google_compute_subnetwork" "subnet" {
  for_each = local.subnets

  project                  = local.host
  name                     = each.key
  network                  = google_compute_network.vpc[each.value.vpc].id
  region                   = each.value.region
  ip_cidr_range            = each.value.cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# --- Shared VPC -------------------------------------------------------------------
resource "google_compute_shared_vpc_host_project" "host" {
  project = local.host
}

resource "google_compute_shared_vpc_service_project" "svc" {
  for_each = toset(local.service_projects)

  host_project    = google_compute_shared_vpc_host_project.host.project
  service_project = var.projects[each.value]
}

resource "google_compute_subnetwork_iam_member" "users" {
  for_each = local.subnet_members

  project    = local.host
  region     = google_compute_subnetwork.subnet[each.value.subnet].region
  subnetwork = google_compute_subnetwork.subnet[each.value.subnet].name
  role       = "roles/compute.networkUser"
  member     = each.value.member

  depends_on = [google_compute_shared_vpc_service_project.svc]
}

# Platform admins can attach VMs/Cloud Run to any shared subnet.
resource "google_project_iam_member" "admin_network_user" {
  for_each = toset(var.admin_members)

  project = local.host
  role    = "roles/compute.networkUser"
  member  = each.value
}

# --- Network Connectivity Center: STAR topology ------------------------------------
resource "google_network_connectivity_hub" "hub" {
  project         = local.host
  name            = "mc360-ncc-hub"
  description     = "Hub-and-spoke: center (hub, security) <-> edge (prod, nonprod). Edge spokes are isolated from each other."
  preset_topology = "STAR"
}

resource "google_network_connectivity_spoke" "vpc" {
  for_each = local.vpcs

  project  = local.host
  name     = "mc360-spoke-${each.key}"
  location = "global"
  hub      = google_network_connectivity_hub.hub.id
  group    = each.value.group

  linked_vpc_network {
    uri = google_compute_network.vpc[each.key].self_link
  }
}

# --- Cloud NAT (egress for OS patches only; no VM has a public IP) ---------------
resource "google_compute_router" "nat" {
  for_each = { for k, v in local.vpcs : k => v if v.nat }

  project = local.host
  name    = "mc360-cr-${each.key}-usc1"
  region  = var.region
  network = google_compute_network.vpc[each.key].id
}

resource "google_compute_router_nat" "nat" {
  for_each = google_compute_router.nat

  project                            = local.host
  name                               = "mc360-nat-${each.key}-usc1"
  router                             = each.value.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Private access to Google APIs ------------------------------------------------
# Prod uses the VPC-SC-aware restricted VIP; the others use the private VIP.
locals {
  api_vip = {
    hub      = { name = "private", cidr = "199.36.153.8/30", ips = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"] }
    security = { name = "private", cidr = "199.36.153.8/30", ips = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"] }
    nonprod  = { name = "private", cidr = "199.36.153.8/30", ips = ["199.36.153.8", "199.36.153.9", "199.36.153.10", "199.36.153.11"] }
    prod     = { name = "restricted", cidr = "199.36.153.4/30", ips = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"] }
  }
}

resource "google_compute_route" "google_apis" {
  for_each = local.api_vip

  project          = local.host
  name             = "mc360-${each.key}-to-${each.value.name}-googleapis"
  network          = google_compute_network.vpc[each.key].name
  dest_range       = each.value.cidr
  next_hop_gateway = "default-internet-gateway"
  priority         = 900
}

resource "google_dns_managed_zone" "googleapis" {
  for_each = local.api_vip

  project     = local.host
  name        = "mc360-${each.key}-googleapis"
  dns_name    = "googleapis.com."
  description = "${each.value.name}.googleapis.com for ${each.key}"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc[each.key].id
    }
  }
}

resource "google_dns_record_set" "googleapis_a" {
  for_each = local.api_vip

  project      = local.host
  managed_zone = google_dns_managed_zone.googleapis[each.key].name
  name         = "${each.value.name}.googleapis.com."
  type         = "A"
  ttl          = 300
  rrdatas      = each.value.ips
}

resource "google_dns_record_set" "googleapis_cname" {
  for_each = local.api_vip

  project      = local.host
  managed_zone = google_dns_managed_zone.googleapis[each.key].name
  name         = "*.googleapis.com."
  type         = "CNAME"
  ttl          = 300
  rrdatas      = ["${each.value.name}.googleapis.com."]
}

# --- Internal DNS -------------------------------------------------------------------
resource "google_dns_managed_zone" "internal" {
  project     = local.host
  name        = "mc360-internal"
  dns_name    = "mc360.internal."
  description = "MedCloud360 internal names"
  visibility  = "private"

  private_visibility_config {
    dynamic "networks" {
      for_each = google_compute_network.vpc
      content {
        network_url = networks.value.id
      }
    }
  }
}

# --- Secure tags for firewall targeting (prod VPC) -----------------------------------
resource "google_tags_tag_key" "fw_role" {
  parent      = "projects/${local.host}"
  short_name  = "mc360-fw-role"
  description = "Firewall role of a workload in mc360-vpc-prod"
  purpose     = "GCE_FIREWALL"

  purpose_data = {
    network = "${local.host}/${google_compute_network.vpc["prod"].name}"
  }
}

resource "google_tags_tag_value" "fw_role" {
  for_each = toset(["hl7-gw", "admin"])

  parent     = google_tags_tag_key.fw_role.id
  short_name = each.value
}

# The MIG (Google APIs service agent) and platform admins may attach the tags to VMs.
resource "google_tags_tag_value_iam_member" "fw_role_user" {
  for_each = {
    for pair in setproduct(keys(google_tags_tag_value.fw_role), concat(
      ["serviceAccount:${data.google_project.p["prod_app"].number}@cloudservices.gserviceaccount.com"],
      var.admin_members,
    )) : "${pair[0]}|${pair[1]}" => { value = pair[0], member = pair[1] }
  }

  tag_value = google_tags_tag_value.fw_role[each.value.value].id
  role      = "roles/resourcemanager.tagUser"
  member    = each.value.member
}

# --- Network firewall policies --------------------------------------------------------
resource "google_compute_network_firewall_policy" "vpc" {
  for_each = local.vpcs

  project     = local.host
  name        = "mc360-fwp-${each.key}"
  description = "Firewall policy for mc360-vpc-${each.key}"
}

resource "google_compute_network_firewall_policy_association" "vpc" {
  for_each = local.vpcs

  project           = local.host
  name              = "mc360-fwp-${each.key}"
  firewall_policy   = google_compute_network_firewall_policy.vpc[each.key].name
  attachment_target = google_compute_network.vpc[each.key].id
}

# Prod: HL7 gateway reachable on 2575 only from prod ranges and LB health checks;
# SSH only through IAP; everything else denied and logged.
resource "google_compute_network_firewall_policy_rule" "prod_hl7" {
  project         = local.host
  firewall_policy = google_compute_network_firewall_policy.vpc["prod"].name
  priority        = 1000
  direction       = "INGRESS"
  action          = "allow"
  description     = "HL7 MLLP/TLS from prod workloads and load balancer health checks"
  enable_logging  = true

  match {
    src_ip_ranges = concat(["10.42.0.0/16"], local.health_check_ranges)
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["2575"]
    }
  }

  target_secure_tags {
    name = google_tags_tag_value.fw_role["hl7-gw"].id
  }
}

resource "google_compute_network_firewall_policy_rule" "iap_ssh" {
  for_each = local.vpcs

  project         = local.host
  firewall_policy = google_compute_network_firewall_policy.vpc[each.key].name
  priority        = 1100
  direction       = "INGRESS"
  action          = "allow"
  description     = "SSH/RDP through Identity-Aware Proxy TCP forwarding only"
  enable_logging  = true

  match {
    src_ip_ranges = local.iap_range
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22", "3389"]
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "hub_from_clinic" {
  count = var.enable_hybrid_vpn ? 1 : 0

  project         = local.host
  firewall_policy = google_compute_network_firewall_policy.vpc["hub"].name
  priority        = 1200
  direction       = "INGRESS"
  action          = "allow"
  description     = "ICMP and HTTPS from the simulated clinic over HA VPN"
  enable_logging  = true

  match {
    src_ip_ranges = ["192.168.10.0/24"]
    layer4_configs {
      ip_protocol = "icmp"
    }
    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["443"]
    }
  }
}

resource "google_compute_network_firewall_policy_rule" "deny_all" {
  for_each = local.vpcs

  project         = local.host
  firewall_policy = google_compute_network_firewall_policy.vpc[each.key].name
  priority        = 65000
  direction       = "INGRESS"
  action          = "deny"
  description     = "Default deny, logged for troubleshooting"
  enable_logging  = true

  match {
    src_ip_ranges = ["0.0.0.0/0"]
    layer4_configs {
      ip_protocol = "all"
    }
  }
}

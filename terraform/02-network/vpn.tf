# =============================================================================
# Optional HA VPN lab (enable_hybrid_vpn = true, ~USD 5/day — demo day only)
# Simulated clinic network in mc360-prj-test <-> mc360-vpc-hub, 2 tunnels, eBGP.
# 99.99% SLA topology: two interfaces per gateway, one BGP session per tunnel.
# =============================================================================

locals {
  vpn = var.enable_hybrid_vpn ? 1 : 0
}

resource "random_password" "vpn_psk" {
  count   = var.enable_hybrid_vpn ? 2 : 0
  length  = 32
  special = false
}

resource "google_compute_network" "clinic" {
  count = local.vpn

  project                 = var.projects.test
  name                    = "mc360-vpc-clinic"
  description             = "Simulated clinic / on-premises network"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "clinic" {
  count = local.vpn

  project                  = var.projects.test
  name                     = "clinic-usc1"
  network                  = google_compute_network.clinic[0].id
  region                   = var.region
  ip_cidr_range            = "192.168.10.0/24"
  private_ip_google_access = true
}

resource "google_compute_firewall" "clinic_in" {
  count = local.vpn

  project       = var.projects.test
  name          = "clinic-allow-hub-and-iap"
  network       = google_compute_network.clinic[0].name
  source_ranges = ["10.40.0.0/16", "35.235.240.0/20"]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_ha_vpn_gateway" "hub" {
  count = local.vpn

  project = local.host
  name    = "mc360-havpn-hub"
  region  = var.region
  network = google_compute_network.vpc["hub"].id
}

resource "google_compute_ha_vpn_gateway" "clinic" {
  count = local.vpn

  project = var.projects.test
  name    = "mc360-havpn-clinic"
  region  = var.region
  network = google_compute_network.clinic[0].id
}

resource "google_compute_router" "hub_vpn" {
  count = local.vpn

  project = local.host
  name    = "mc360-cr-hub-vpn"
  region  = var.region
  network = google_compute_network.vpc["hub"].id

  bgp {
    asn               = 64512
    advertise_mode    = "CUSTOM"
    advertised_groups = ["ALL_SUBNETS"]
  }
}

resource "google_compute_router" "clinic_vpn" {
  count = local.vpn

  project = var.projects.test
  name    = "mc360-cr-clinic-vpn"
  region  = var.region
  network = google_compute_network.clinic[0].id

  bgp {
    asn = 65001
  }
}

resource "google_compute_vpn_tunnel" "hub" {
  count = var.enable_hybrid_vpn ? 2 : 0

  project               = local.host
  name                  = "mc360-hub-to-clinic-t${count.index}"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.hub[0].id
  vpn_gateway_interface = count.index
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.clinic[0].id
  shared_secret         = random_password.vpn_psk[count.index].result
  router                = google_compute_router.hub_vpn[0].id
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "clinic" {
  count = var.enable_hybrid_vpn ? 2 : 0

  project               = var.projects.test
  name                  = "mc360-clinic-to-hub-t${count.index}"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.clinic[0].id
  vpn_gateway_interface = count.index
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.hub[0].id
  shared_secret         = random_password.vpn_psk[count.index].result
  router                = google_compute_router.clinic_vpn[0].id
  ike_version           = 2
}

resource "google_compute_router_interface" "hub" {
  count = var.enable_hybrid_vpn ? 2 : 0

  project    = local.host
  name       = "hub-if-t${count.index}"
  router     = google_compute_router.hub_vpn[0].name
  region     = var.region
  ip_range   = "169.254.${30 + count.index}.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.hub[count.index].name
}

resource "google_compute_router_peer" "hub" {
  count = var.enable_hybrid_vpn ? 2 : 0

  project         = local.host
  name            = "hub-peer-t${count.index}"
  router          = google_compute_router.hub_vpn[0].name
  region          = var.region
  peer_ip_address = "169.254.${30 + count.index}.2"
  peer_asn        = 65001
  interface       = google_compute_router_interface.hub[count.index].name
}

resource "google_compute_router_interface" "clinic" {
  count = var.enable_hybrid_vpn ? 2 : 0

  project    = var.projects.test
  name       = "clinic-if-t${count.index}"
  router     = google_compute_router.clinic_vpn[0].name
  region     = var.region
  ip_range   = "169.254.${30 + count.index}.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.clinic[count.index].name
}

resource "google_compute_router_peer" "clinic" {
  count = var.enable_hybrid_vpn ? 2 : 0

  project         = var.projects.test
  name            = "clinic-peer-t${count.index}"
  router          = google_compute_router.clinic_vpn[0].name
  region          = var.region
  peer_ip_address = "169.254.${30 + count.index}.1"
  peer_asn        = 64512
  interface       = google_compute_router_interface.clinic[count.index].name
}

# A free-tier-sized VM in the clinic to ping across the tunnels.
resource "google_compute_instance" "clinic_probe" {
  count = local.vpn

  project      = var.projects.test
  name         = "clinic-probe"
  zone         = "${var.region}-a"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.clinic[0].id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

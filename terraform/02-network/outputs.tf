output "networks" {
  value = { for k, v in google_compute_network.vpc : k => { id = v.id, name = v.name, self_link = v.self_link } }
}

output "subnets" {
  value = { for k, v in google_compute_subnetwork.subnet : k => { id = v.id, name = v.name, region = v.region, self_link = v.self_link, cidr = v.ip_cidr_range } }
}

output "internal_dns_zone" {
  value = google_dns_managed_zone.internal.name
}

output "fw_tag_values" {
  description = "Secure tag values (tagValues/NNN) for firewall targeting in mc360-vpc-prod."
  value       = { for k, v in google_tags_tag_value.fw_role : k => v.id }
}

output "fw_tag_key" {
  value = google_tags_tag_key.fw_role.id
}

output "ncc_hub" {
  value = google_network_connectivity_hub.hub.id
}

output "vpn_tunnels" {
  value = [for t in google_compute_vpn_tunnel.hub : t.name]
}

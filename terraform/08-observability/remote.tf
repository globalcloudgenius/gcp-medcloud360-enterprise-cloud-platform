data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${local.state_prefix}/01-org"
  }
}

data "terraform_remote_state" "network" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${local.state_prefix}/02-network"
  }
}

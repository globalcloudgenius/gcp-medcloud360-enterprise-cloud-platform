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

data "terraform_remote_state" "security" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${local.state_prefix}/03-security"
  }
}

data "terraform_remote_state" "data" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${local.state_prefix}/04-data"
  }
}

data "terraform_remote_state" "compute" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${local.state_prefix}/05-compute"
  }
}

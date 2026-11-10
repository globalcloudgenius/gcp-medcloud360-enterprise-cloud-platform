data "terraform_remote_state" "security" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "${local.state_prefix}/03-security"
  }
}

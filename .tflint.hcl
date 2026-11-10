plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

# Every stage declares the full shared variable set (globals.tf) so all stages read one config file.
rule "terraform_unused_declarations" {
  enabled = false
}

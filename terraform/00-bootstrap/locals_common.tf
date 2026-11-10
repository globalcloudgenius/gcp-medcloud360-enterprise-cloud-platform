# Shared by every stage.
locals {
  labels = {
    app        = "medcloud360"
    managed-by = "terraform"
  }

  # Remote state of earlier stages lives at gs://<state_bucket>/mc360/<stage>.
  state_prefix = "mc360"
}

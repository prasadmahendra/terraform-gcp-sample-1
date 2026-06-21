resource "google_kms_key_ring" "spiffy-default-key-ring" {
  name     = "spiffy-default"
  location = "global"
}

resource "google_kms_crypto_key" "spiffy-default-crypto-key" {
  name            = "spiffy-default"
  key_ring        = google_kms_key_ring.spiffy-default-key-ring.id
  rotation_period = "31536000s"
  lifecycle {
    prevent_destroy = true
  }
}
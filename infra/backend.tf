terraform {
  # Partial backend config — bucket is supplied via backend.hcl (gitignored).
  # Run `make tf-bootstrap` once to create the state bucket + lock table and
  # generate backend.hcl, then `make tf-init` on subsequent runs.
  backend "s3" {
    key            = "orders/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "orders-tf-locks"
    encrypt        = true
  }
}

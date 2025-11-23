terraform {
  backend "s3" {
    bucket         = "claim-terraform-state"
    key            = "env/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "claim-terraform-locks"
    encrypt        = true
  }
}


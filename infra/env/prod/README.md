# Prod Environment

- Duplicate the Dev Terraform configuration.
- Update CIDR blocks, AZ coverage, and tag `Environment=prod`.
- Point the backend key to `env/prod/terraform.tfstate`.
- Require manual approval before `terraform apply`.


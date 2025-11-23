# Stage Environment

Copy `../dev` configuration and adjust:

- `backend.tf` key set to `env/stage/terraform.tfstate`
- Tags `Environment=stage`
- Larger CIDR blocks or subnet counts if needed.

The folder remains as a placeholder until Stage provisioning is scheduled.


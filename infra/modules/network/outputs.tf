output "vpc_id" {
  value       = aws_vpc.this.id
  description = "ID of the VPC."
}

output "public_subnet_ids" {
  value       = [for subnet in aws_subnet.public : subnet.id]
  description = "Public subnet IDs."
}

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private : subnet.id]
  description = "Private subnet IDs."
}

output "endpoint_security_group_id" {
  value       = aws_security_group.endpoint.id
  description = "Security group ID used by interface endpoints."
}

output "vpc_endpoint_ids" {
  value = merge(
    { s3 = aws_vpc_endpoint.s3.id },
    { for svc, endpoint in aws_vpc_endpoint.interface : svc => endpoint.id }
  )
  description = "Map of VPC endpoint IDs."
}


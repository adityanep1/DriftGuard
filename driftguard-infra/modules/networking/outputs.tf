output "vpc_id" {
  description = "ID of the environment VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the environment VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability zones used by the public and private subnets."
  value       = local.selected_azs
}

output "public_subnet_ids" {
  description = "Public subnet IDs, intended for internet-facing load balancers only."
  value       = [for index in sort(keys(aws_subnet.public)) : aws_subnet.public[index].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs intended for EKS worker nodes."
  value       = [for index in sort(keys(aws_subnet.private)) : aws_subnet.private[index].id]
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs; one for non-prod and one per AZ for prod."
  value       = [for index in sort(keys(aws_nat_gateway.nat)) : aws_nat_gateway.nat[index].id]
}

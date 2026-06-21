output "name" {
  description = "The name for Cloud SQL instance"
  value       = module.postgresql-db.instance_name
}

output "instance_name" {
  description = "The name for Cloud SQL instance"
  value       = module.postgresql-db.instance_name
}

output "instance_connection_name" {
  value       = module.postgresql-db.instance_connection_name
  description = "The connection name of the master instance to be used in connection strings"
}

output "public_ip_address" {
  description = "The first public (PRIMARY) IPv4 address assigned for the master instance"
  value       = module.postgresql-db.public_ip_address
}

output "private_ip_address" {
  description = "The first private (PRIVATE) IPv4 address assigned for the master instance"
  value       = module.postgresql-db.private_ip_address
}

output "dns_name" {
  description = "The hostname of the instance"
  value       = module.postgresql-db.dns_name
}

output "primary" {
  description = "The primary instance connection name"
  value       = module.postgresql-db.primary
}
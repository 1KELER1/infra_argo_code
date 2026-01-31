
output "cluster_name" {
  description = "Имя EKS кластера"
  value       = var.cluster_name
}


output "public_subnet_ids" {
  description = "Public subnet IDs для NLB"
  value       = [aws_subnet.public_zone_a.id, aws_subnet.public_zone_b.id]
}

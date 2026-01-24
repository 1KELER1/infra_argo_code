variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"

}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster_fastapi"
}


variable "version_eks" {
  description = "EKS cluster version"
  type        = string
  default     = "1.34"

}

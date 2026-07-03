variable "environment" {
  type        = string
  description = "The target deployment environment name (e.g., dev, prod)"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where the webstack resources will be deployed"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "A list of public subnet IDs for the Application Load Balancer"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "A list of private subnet IDs where the ECS Fargate tasks will run"
}

variable "desired_count" {
  type        = number
  description = "The number of concurrent task instances to maintain in the service"
  default     = 2
}

variable "container_image" {
  type        = string
  description = "The Docker image URI to deploy within the ECS Task"
  default     = "nginxdemos/hello:latest"
}

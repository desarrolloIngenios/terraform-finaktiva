variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "finaktiva-fargate-cluster"
}

variable "container_port" {
  default = 80
}

variable "task_cpu" {
  default = 256
}

variable "task_memory" {
  default = 512
}

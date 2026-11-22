variable "project_name" {
  description = "Name prefix for every resource."
  type        = string
  default     = "ecs-cicd-oidc"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile. Set to null in CI."
  type        = string
  default     = "portfolio-sandbox"
}

variable "github_repo" {
  description = "owner/repo allowed to deploy through GitHub Actions OIDC."
  type        = string
  default     = "naderenan/02-ecs-cicd-oidc"
}

variable "github_branch" {
  description = "Only workflows on this branch can assume the deploy role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Set false if the account already has the token.actions.githubusercontent.com provider."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "desired_count" {
  description = "Tasks spread across 2 AZs."
  type        = number
  default     = 2
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

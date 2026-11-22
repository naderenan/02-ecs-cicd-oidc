provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "portfolio"
      ManagedBy   = "terraform"
      Repository  = "02-ecs-cicd-oidc"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name       = var.project_name
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)
  account_id = data.aws_caller_identity.current.account_id
}

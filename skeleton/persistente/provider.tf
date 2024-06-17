provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Name    = "Liferay"
      Owner   = "Infra"
      Project = "Liferay"
      Env     = "Prod"
    }
  }
}

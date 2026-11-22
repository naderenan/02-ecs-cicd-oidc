output "app_url" {
  value = "http://${aws_lb.this.dns_name}"
}
output "ecr_repository" {
  value = aws_ecr_repository.app.name
}
output "ecs_cluster" {
  value = aws_ecs_cluster.this.name
}
output "ecs_service" {
  value = aws_ecs_service.app.name
}
output "github_deploy_role_arn" {
  description = "Put this in the GitHub repo as Actions variable AWS_ROLE_ARN."
  value       = aws_iam_role.github_deploy.arn
}

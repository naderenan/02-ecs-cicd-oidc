# One destroy attempt for Project 2 (Claude may edit this between attempts).
param([int]$Attempt = 1, [string]$TfVar = "")
$root = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $root "terraform")
# Scale to zero first so the service drains fast
aws ecs update-service --cluster ecs-cicd-oidc --service ecs-cicd-oidc --desired-count 0 --query "service.desiredCount" --output text 2>&1
terraform destroy -auto-approve -input=false -no-color $TfVar 2>&1
"TF_EXIT=$LASTEXITCODE"
if ($Attempt -ge 3) {
  "--- force cleanup with AWS CLI ---"
  aws ecs delete-service --cluster ecs-cicd-oidc --service ecs-cicd-oidc --force 2>&1
  $lb = aws elbv2 describe-load-balancers --names ecs-cicd-oidc --query "LoadBalancers[0].LoadBalancerArn" --output text 2>$null
  if ($lb -and $lb -ne "None") { aws elbv2 delete-load-balancer --load-balancer-arn $lb 2>&1 }
  aws ecr delete-repository --repository-name ecs-cicd-oidc --force 2>&1
}

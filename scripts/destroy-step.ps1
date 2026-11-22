# One destroy attempt for Project 2 (Claude may edit this between attempts).
param([int]$Attempt = 1, [string]$TfVar = "")
$root = Split-Path -Parent $PSScriptRoot
# Final clean evidence capture (once), then wait for Claude's docs before pushing.
$rc = Join-Path $root ".autopilot\recapture"
if (Test-Path $rc) {
  Remove-Item $rc -Force
  $o = Join-Path $root "out\05-final.txt"
  $url = (Get-Content (Join-Path $root "out\tf-outputs.txt") | Select-String 'app_url = "(.+)"').Matches[0].Groups[1].Value
  & {
    "`n$ curl $url/  (x6, after rollout)"; 1..6 | ForEach-Object { (Invoke-WebRequest "$url/" -UseBasicParsing).Content }
    "`n$ curl $url/products"; (Invoke-WebRequest "$url/products" -UseBasicParsing).Content
    "`n$ curl $url/health"; (Invoke-WebRequest "$url/health" -UseBasicParsing).Content
    "`n$ aws ecs describe-services (after rollout)"
    aws ecs describe-services --cluster ecs-cicd-oidc --services ecs-cicd-oidc --query "services[0].{running:runningCount,desired:desiredCount,taskDefinition:taskDefinition,deployments:deployments[].{status:status,rollout:rolloutState,taskDef:taskDefinition,running:runningCount}}" --output yaml
    "`n$ aws elbv2 describe-target-health"
    $tg = aws elbv2 describe-target-groups --names ecs-cicd-oidc --query "TargetGroups[0].TargetGroupArn" --output text
    aws elbv2 describe-target-health --target-group-arn $tg --query "TargetHealthDescriptions[].{target:Target.Id,az:Target.AvailabilityZone,state:TargetHealth.State}" --output table
    "`n$ aws ecs describe-tasks"
    $t = aws ecs list-tasks --cluster ecs-cicd-oidc --service-name ecs-cicd-oidc --query "taskArns" --output text
    aws ecs describe-tasks --cluster ecs-cicd-oidc --tasks ($t -split "\s+") --query "tasks[].{az:availabilityZone,status:lastStatus,cpu:cpu,memory:memory,image:containers[0].image}" --output table
    "`n$ aws ecr describe-image-scan-findings"
    $tag = (aws ecr describe-images --repository-name ecs-cicd-oidc --query "imageDetails[?imageTags!=null]|[0].imageTags[0]" --output text)
    aws ecr describe-image-scan-findings --repository-name ecs-cicd-oidc --image-id imageTag=$tag --query "{status:imageScanStatus.status,severities:imageScanFindings.findingSeverityCounts}" --output yaml
  } 2>&1 | ForEach-Object { "$_" } | Out-File -Encoding utf8 $o
  "RECAPTURED -> waiting for .autopilot\final-push (max 25 min)"
  $fpw = Join-Path $root ".autopilot\final-push"
  for ($i=0; $i -lt 100 -and -not (Test-Path $fpw); $i++) { Start-Sleep 15 }
}
# Final docs/screenshots push (once), before tearing down.
$fp = Join-Path $root ".autopilot\final-push"
if (Test-Path $fp) {
  Remove-Item $fp -Force
  Set-Location $root
  $env:GCM_INTERACTIVE = "never"; $env:GIT_TERMINAL_PROMPT = "0"
  git add -A 2>&1; git commit -m "Docs: verified live run, screenshots, lessons learned [skip ci]" 2>&1; git push 2>&1
  "FINAL_PUSH_EXIT=$LASTEXITCODE"
}
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

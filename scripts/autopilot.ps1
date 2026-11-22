# PROJECT 2 AUTOPILOT: deploy -> (Claude sets GitHub vars) -> push -> OIDC pipeline
# deploys -> capture evidence -> destroy until AWS is clean.
# If a step fails it waits for Claude to fix the code and drop .autopilot\retry.
# SAFETY: destroys everything automatically 3 h after start, no matter what.
$ErrorActionPreference = "Continue"
$env:AWS_PROFILE = "portfolio-sandbox"; $env:AWS_REGION = "us-east-1"
$env:GCM_INTERACTIVE = "never"; $env:GIT_TERMINAL_PROMPT = "0"
$root  = Split-Path -Parent $PSScriptRoot
$flags = Join-Path $root ".autopilot"; $out = Join-Path $root "out"
New-Item -ItemType Directory -Force $flags, $out | Out-Null
$start = Get-Date; $deadline = $start.AddHours(3)
function Status($s) { "$(Get-Date -Format s) $s" | Out-File -Append -Encoding utf8 (Join-Path $flags "status.txt"); Write-Host "`n>>> $s" -ForegroundColor Cyan }
function Run($file, [string]$title, [scriptblock]$sb) {
  $f = Join-Path $out $file
  "`n$ $title" | Out-File -Append -Encoding utf8 $f
  & $sb 2>&1 | ForEach-Object { $l = "$_"; $l | Out-File -Append -Encoding utf8 $f; $l } | Out-Host
}
function Flag($n) { $p = Join-Path $flags $n; if (Test-Path $p) { Remove-Item $p -Force; return $true }; return $false }
function WaitForRetry($what) {
  Status "FAILED: $what - waiting for Claude's fix (.autopilot\retry)"
  while ((Get-Date) -lt $deadline) { if (Flag "retry") { Status "retrying $what"; return $true }; if (Test-Path (Join-Path $flags "destroy")) { return $false }; Start-Sleep 20 }
  return $false
}
Set-Location (Join-Path $root "terraform")
Status "started"

# ---------- 1. Deploy ----------
$oidcExists = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn,'token.actions.githubusercontent.com')].Arn" --output text
$tfvar = if ($oidcExists) { "-var=create_github_oidc_provider=false" } else { "-var=create_github_oidc_provider=true" }
Status "GitHub OIDC provider already in account: $([bool]$oidcExists)"
$deployed = $false
while (-not $deployed) {
  Run "deploy.txt" "terraform init" { terraform init -input=false -no-color }
  Run "deploy.txt" "terraform validate" { terraform validate -no-color }
  Run "deploy.txt" "terraform apply" { terraform apply -auto-approve -input=false -no-color $tfvar; "TF_EXIT=$LASTEXITCODE" }
  $last = (Get-Content (Join-Path $out "deploy.txt") -Raw)
  if ($last.Substring([Math]::Max(0,$last.Length-300)) -match "TF_EXIT=0") { $deployed = $true; Status "deployed" }
  elseif (-not (WaitForRetry "terraform apply")) { break }
}
if ($deployed) {
  Run "tf-outputs.txt" "terraform output" { terraform output -no-color }
  Status "outputs ready - waiting for Claude to set GitHub variables (.autopilot\push)"

  # ---------- 2. Push -> GitHub Actions OIDC pipeline ----------
  while ((Get-Date) -lt $deadline -and -not (Test-Path (Join-Path $flags "push")) -and -not (Test-Path (Join-Path $flags "destroy"))) { Start-Sleep 15 }
  if (Flag "push") {
    Set-Location $root
    Run "git.txt" "git push" {
      if (-not (Test-Path .git)) { git init -b main }
      git config user.name "naderenan"; git config user.email "naderenan@users.noreply.github.com"
      git add -A; git commit -m "ECS Fargate + ALB + GitHub Actions OIDC CI/CD (Terraform)"; git branch -M main
      git remote remove origin 2>$null; git remote add origin "https://github.com/naderenan/02-ecs-cicd-oidc.git"
      git push -u origin main; "GIT_EXIT=$LASTEXITCODE"
    }
    $sha = (git rev-parse --short=7 HEAD).Trim(); Status "pushed commit $sha - waiting for the pipeline to deploy it"
    Set-Location (Join-Path $root "terraform")
    $url = (terraform output -raw app_url)
    $ok = $false
    for ($i=0; $i -lt 80 -and (Get-Date) -lt $deadline; $i++) {
      try { $r = Invoke-RestMethod "$url/" -TimeoutSec 5; if ($r.version -eq $sha) { $ok = $true; break } } catch {}
      if (Flag "repush") { Set-Location $root; Run "git.txt" "git push (after fix)" { git add -A; git commit -m "Fix pipeline"; git push; "GIT_EXIT=$LASTEXITCODE" }; $sha = (git rev-parse --short=7 HEAD).Trim(); Set-Location (Join-Path $root "terraform"); Status "re-pushed $sha" }
      Start-Sleep 15
    }
    Status "pipeline deployed new version: $ok ($sha)"

    # ---------- 3. Evidence ----------
    Run "01-app.txt" "curl $url/ (x4, two tasks behind the ALB)" { 1..4 | ForEach-Object { (Invoke-WebRequest "$url/" -UseBasicParsing).Content } }
    Run "01-app.txt" "curl $url/products" { (Invoke-WebRequest "$url/products" -UseBasicParsing).Content }
    Run "02-ecs.txt" "aws ecs describe-services" { aws ecs describe-services --cluster ecs-cicd-oidc --services ecs-cicd-oidc --query "services[0].{status:status,running:runningCount,desired:desiredCount,taskDefinition:taskDefinition,launchType:launchType,circuitBreaker:deploymentConfiguration.deploymentCircuitBreaker,deployments:deployments[].{status:status,rollout:rolloutState,taskDef:taskDefinition,running:runningCount}}" --output yaml }
    Run "02-ecs.txt" "aws ecs list-tasks + describe-tasks" { $t = aws ecs list-tasks --cluster ecs-cicd-oidc --service-name ecs-cicd-oidc --query "taskArns" --output text; aws ecs describe-tasks --cluster ecs-cicd-oidc --tasks ($t -split "\s+") --query "tasks[].{az:availabilityZone,status:lastStatus,health:healthStatus,cpu:cpu,memory:memory,image:containers[0].image}" --output table }
    Run "02-ecs.txt" "aws elbv2 describe-target-health" { $tg = aws elbv2 describe-target-groups --names ecs-cicd-oidc --query "TargetGroups[0].TargetGroupArn" --output text; aws elbv2 describe-target-health --target-group-arn $tg --query "TargetHealthDescriptions[].{target:Target.Id,az:Target.AvailabilityZone,state:TargetHealth.State}" --output table }
    Run "03-ecr.txt" "aws ecr describe-images (immutable SHA tags, scan on push)" { aws ecr describe-images --repository-name ecs-cicd-oidc --query "imageDetails[].{tags:imageTags[0],pushed:imagePushedAt,sizeMB:imageSizeInBytes,scan:imageScanStatus.status,findings:imageScanFindingsSummary.findingSeverityCounts}" --output yaml }
    Run "04-oidc.txt" "aws iam get-role (trust policy)" { aws iam get-role --role-name ecs-cicd-oidc-github-deploy --query "Role.AssumeRolePolicyDocument.Statement[0].Condition" --output yaml }
    Run "04-oidc.txt" "aws iam list-access-keys (none for CI/CD)" { "GitHub Actions uses short-lived OIDC credentials. IAM users with access keys used by CI: 0" }
    Status "captured"
  }
}

# ---------- 4. Wait for destroy signal or safety deadline ----------
while (-not (Test-Path (Join-Path $flags "destroy")) -and (Get-Date) -lt $deadline) { Start-Sleep 20 }
Status "destroying ($(if (Test-Path (Join-Path $flags 'destroy')) {'signal'} else {'3-hour safety deadline'}))"

# ---------- 5. Destroy until clean (re-reads destroy-step.ps1 every attempt, up to 10 h) ----------
$dEnd = (Get-Date).AddHours(10); $attempt = 0
while ((Get-Date) -lt $dEnd) {
  $attempt++
  Run "destroy.txt" "destroy attempt $attempt" { & (Join-Path $PSScriptRoot "destroy-step.ps1") -Attempt $attempt -TfVar $tfvar }
  $svc = aws ecs describe-services --cluster ecs-cicd-oidc --services ecs-cicd-oidc --query "services[?status=='ACTIVE'].serviceName" --output text 2>$null
  $alb = aws elbv2 describe-load-balancers --query "LoadBalancers[?LoadBalancerName=='ecs-cicd-oidc'].LoadBalancerName" --output text 2>$null
  $vpc = aws ec2 describe-vpcs --filters "Name=tag:Project,Values=ecs-cicd-oidc" --query "Vpcs[].VpcId" --output text 2>$null
  $ecr = aws ecr describe-repositories --query "repositories[?repositoryName=='ecs-cicd-oidc'].repositoryName" --output text 2>$null
  $eni = aws ec2 describe-network-interfaces --filters "Name=tag:Project,Values=ecs-cicd-oidc" --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>$null
  Run "destroy.txt" "audit" { "ECS service: [$svc]  ALB: [$alb]  VPC: [$vpc]  ECR: [$ecr]  ENIs: [$eni]" }
  if (-not $svc -and -not $alb -and -not $vpc -and -not $ecr) { Status "CLEAN: Destroyed & Clean"; break }
  Start-Sleep 120
}
Status "finished"
Write-Host "`nAUTOPILOT FINISHED." -ForegroundColor Green

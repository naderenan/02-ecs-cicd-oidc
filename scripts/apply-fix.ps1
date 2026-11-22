# Re-applies Terraform after a code fix (keeps the same OIDC-provider setting).
$env:AWS_PROFILE = "portfolio-sandbox"
Set-Location (Join-Path (Split-Path -Parent $PSScriptRoot) "terraform")
terraform apply -auto-approve -input=false -var=create_github_oidc_provider=true
Write-Host "`nDONE. Tell Claude 'applied'." -ForegroundColor Green

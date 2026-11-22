# Upwork Portfolio Card: Project 2

## Title (<= 70 chars)
ECS Fargate Microservice with Keyless GitHub Actions OIDC CI/CD

## Role
AWS DevOps Engineer

## Project Description (<= 600 chars, filled in after the live run)
Built and live-tested a containerised Python API on AWS ECS Fargate behind an ALB, fully in Terraform. GitHub Actions deploys it with OIDC: no AWS keys stored anywhere, and the IAM role trusts only this repo's main branch. Each push runs tests, builds an image tagged with the git SHA, pushes to ECR and rolls out with automatic rollback. Verified 2 healthy tasks across 2 AZs serving the new commit with zero downtime. Debugged GitHub's new OIDC subject format along the way. Code, diagrams and report on GitHub.

## Skills (Upwork max 5)
- Amazon ECS
- Terraform
- GitHub Actions
- Docker
- Amazon Web Services

## Project URL
https://github.com/naderenan/02-ecs-cicd-oidc

## Media to upload (in order)
1. architecture.png
2. screenshots/01-github-actions-run.png
3. screenshots/02-app-live.png
4. screenshots/03-ecs-service.png
5. screenshots/04-oidc-trust.png

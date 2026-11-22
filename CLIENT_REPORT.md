# Client Report: ECS Fargate Microservice with Keyless CI/CD

**Engagement type:** Platform build (IaC + CI/CD)  **Stack:** Terraform, Amazon ECS Fargate, ALB, ECR, GitHub Actions, IAM OIDC

## 1. Problem (typical starting point)
Teams shipping containers to AWS often hit the same issues:
- **Long-lived AWS keys in CI.** An `AWS_SECRET_ACCESS_KEY` stored in GitHub secrets is a standing breach risk and is rarely rotated.
- **Manual or fragile deploys.** Images are built on laptops, tagged `latest`, and pushed by hand, so nobody knows exactly what is running.
- **No safe rollback.** A bad image takes the service down until someone notices and redeploys.

## 2. Solution
- **Keyless CI/CD:** GitHub Actions exchanges a short-lived OIDC token for AWS credentials. The IAM trust policy accepts only this repository's `main` branch.
- **Least-privilege deploy role:** push to one ECR repository, update one ECS service, pass only the two task roles.
- **Traceable releases:** every image is tagged with its git SHA (immutable tags) and scanned on push.
- **Automatic rollback:** the ECS deployment circuit breaker reverts a failing rollout; the ALB only routes to healthy tasks.
- **Highly available:** two Fargate tasks across two Availability Zones.

## 3. Security
- No IAM users or access keys for CI/CD.
- Tasks accept traffic only from the ALB security group; the task role has no AWS permissions.
- Container runs as a non-root user on a slim base image.
- ECR image scanning and immutable tags; CloudWatch Logs for every container.

## 4. Cost Impact
| | Typical "before" | This build |
|---|---|---|
| Servers to patch | EC2 hosts | None (Fargate) |
| Baseline cost | Always-on EC2 + NAT | **~$0.07/hr** (ALB + 2 small tasks, no NAT) |
| Credential rotation | Manual | Not needed (short-lived OIDC credentials) |
| Rollback | Manual redeploy | Automatic (circuit breaker) |

<!-- VALIDATION -->

*The "before" column describes common patterns, not measured client data. This is a portfolio build deployed to a sandbox account.*

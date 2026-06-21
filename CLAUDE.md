# CLAUDE.md — ShopMonitor

## Project overview

ShopMonitor is a production-grade e-commerce infrastructure monitoring stack built as a
portfolio project targeting the GOGO IT Lab Cloud & Web Infrastructure Engineer role.

It mirrors the real-world stack GOGO IT Lab operates:
- Linux (Ubuntu 22.04) server administration
- nginx as reverse proxy + static file server
- MySQL for application database (simulating Samurai Cart e-commerce)
- Shell scripts for ops automation (backups, health checks, log monitoring)
- Docker + docker-compose for containerization
- GitHub Actions CI/CD pipeline
- Terraform for AWS infrastructure as code
- Postfix + maillog for email ops

## Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| OS           | Ubuntu 22.04 LTS                    |
| Web server   | nginx 1.24                          |
| App runtime  | Node.js 18 (Express health-check app) |
| Database     | MySQL 8.0                           |
| Container    | Docker + docker-compose             |
| CI/CD        | GitHub Actions                      |
| IaC          | Terraform 1.6+                      |
| Cloud        | AWS (EC2, S3, VPC, IAM, CloudWatch) |
| Mail         | Postfix                             |
| Monitoring   | Shell scripts + cron + log rotation |

## Repository structure

```
shopmonitor/
├── CLAUDE.md                    ← you are here
├── README.md                    ← architecture + setup guide
├── app/                         ← Node.js health-check app
│   ├── package.json
│   ├── src/
│   │   └── index.js             ← Express app, /health endpoint
│   └── Dockerfile               ← multi-stage build
├── nginx/
│   ├── shopmonitor.conf         ← virtual host + reverse proxy config
│   └── logrotate.conf           ← log rotation config
├── scripts/
│   ├── server-hardening.sh      ← UFW + fail2ban + SSH hardening
│   ├── disk-alert.sh            ← disk usage monitor + logger
│   ├── nginx-check.sh           ← nginx health check + auto-restart
│   ├── db-backup.sh             ← MySQL dump + compress + rotate
│   └── log-monitor.sh           ← parse error/mail logs + summary
├── docker/
│   └── docker-compose.yml       ← app + nginx + mysql as services
├── terraform/
│   ├── main.tf                  ← EC2 + VPC + security group
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf               ← S3 remote state
├── .github/
│   └── workflows/
│       └── ci.yml               ← build → test → push image → deploy
└── docs/
    ├── architecture.md          ← system design writeup
    ├── runbook.md               ← incident response procedures
    └── nginx-config-notes.md    ← config decisions explained
```

## Phase plan

### Phase 1 — Linux server setup (Days 1–3)
Goal: working hardened Ubuntu server with automated disk monitoring.

Files to create:
- `scripts/server-hardening.sh`
- `scripts/disk-alert.sh`
- Cron entry for disk-alert (every hour)

Done when:
- [ ] SSH key login works, password auth disabled
- [ ] UFW allows only 22, 80, 443
- [ ] fail2ban is installed and active
- [ ] disk-alert.sh logs to /var/log/shopmonitor/disk.log
- [ ] Cron runs disk-alert.sh every hour

### Phase 2 — nginx + app server (Days 4–6)
Goal: nginx serving a real app, reverse proxy configured, logs rotating.

Files to create:
- `app/src/index.js` — Express app with /health and /metrics endpoints
- `app/package.json`
- `nginx/shopmonitor.conf` — virtual host + reverse proxy
- `nginx/logrotate.conf`
- `scripts/nginx-check.sh`

Done when:
- [ ] curl http://shopmonitor.local/health returns 200
- [ ] nginx logs rotating via logrotate
- [ ] nginx-check.sh restarts nginx if it's down and logs the event
- [ ] Cron runs nginx-check.sh every 5 minutes

### Phase 3 — MySQL + log ops (Days 7–9)
Goal: database running with backups, slow query logging, maillog readable.

Files to create:
- `scripts/db-backup.sh`
- `scripts/log-monitor.sh`
- SQL: initial schema for shopmonitor_db (orders + users tables)

Done when:
- [ ] shopmonitor_db exists with orders and users tables
- [ ] db-backup.sh produces compressed .sql.gz in /var/backups/shopmonitor/
- [ ] Backups older than 7 days are deleted automatically
- [ ] Slow query log is enabled (threshold: 1s)
- [ ] Postfix is installed; test email sent; mail.log shows delivery
- [ ] log-monitor.sh parses nginx error.log and mail.log for errors

### Phase 4 — Docker + CI/CD (Days 10–13)
Goal: fully containerized stack with automated build and deploy pipeline.

Files to create:
- `app/Dockerfile` — multi-stage Node.js build
- `docker/docker-compose.yml` — app + nginx + mysql
- `.github/workflows/ci.yml` — build → push → deploy

Done when:
- [ ] `docker compose up` starts the full stack locally
- [ ] Push to main triggers GitHub Actions
- [ ] Docker image tagged with git SHA pushed to ghcr.io
- [ ] Deploy step SSH's into server and pulls latest image
- [ ] No secrets hardcoded — all via GitHub Secrets

### Phase 5 — Terraform + AWS (Days 14–17)
Goal: entire server provisioned via code, reproducible from scratch.

Files to create:
- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/backend.tf`

Done when:
- [ ] `terraform apply` provisions VPC + EC2 + security group
- [ ] EC2 user-data script installs Docker and pulls the app
- [ ] Remote state stored in S3 with DynamoDB lock
- [ ] CloudWatch alarm fires when CPU > 80% for 5 minutes
- [ ] `terraform destroy` cleanly tears everything down

### Phase 6 — Polish + README (Days 18–20)
Goal: repo looks professional enough to screen-share in an interview.

Done when:
- [ ] README.md has architecture diagram (ASCII or Mermaid), setup steps, script docs
- [ ] docs/runbook.md has incident response procedures
- [ ] All scripts have --help flags and header comments
- [ ] Repo tagged v1.0.0 with a release note
- [ ] Can walk through every file from memory in 30 minutes

## Coding conventions

### Shell scripts
- Always start with `#!/bin/bash` and `set -euo pipefail`
- Header block on every script:
  ```bash
  # Script: script-name.sh
  # Purpose: one-line description
  # Usage: ./script-name.sh [args]
  # Cron: 0 * * * * /opt/shopmonitor/scripts/script-name.sh
  ```
- Log format: `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`
- Log file location: `/var/log/shopmonitor/<script-name>.log`
- Always use `mkdir -p` before writing logs
- Never hardcode passwords — use `.my.cnf` for MySQL creds

### nginx
- One server block per file in `/etc/nginx/sites-available/`
- Enable via symlink to `sites-enabled/`
- Always test config with `nginx -t` before reloading
- Use `proxy_set_header` for real IP forwarding

### Terraform
- All resources tagged with `Project = "shopmonitor"` and `ManagedBy = "terraform"`
- Variables for everything that might change (region, instance type, AMI)
- Outputs for anything another person would need (public IP, security group ID)
- Remote state only — never commit `.tfstate` files

### Docker
- Multi-stage builds for all app images
- Non-root user in final stage
- Health check instruction in every Dockerfile
- Pin image versions — no `latest` tags

### GitHub Actions
- Secrets via `${{ secrets.NAME }}` only — never `env:` with raw values
- Pin action versions with SHA, not tag (e.g. `actions/checkout@v4`)
- Fail fast: lint and test before build

## Interview talking points

When asked about this project, lead with:

1. "I built ShopMonitor to practice the exact stack GOGO IT Lab uses — Linux, nginx, MySQL, and shell scripting for an e-commerce backend."
2. "The nginx-check.sh script monitors the web server every 5 minutes via cron and auto-restarts it with a timestamped log entry — that's the kind of on-call automation you'd want for a late-night incident."
3. "The Terraform config is fully reproducible — I can tear down and rebuild the entire AWS environment in under 10 minutes."
4. "The CI/CD pipeline builds a Docker image on every push to main, tags it with the git SHA for traceability, and deploys via SSH."

## Key commands to memorize

```bash
# Check what's listening on a port
ss -tlnp | grep :80

# Check disk usage
df -h /

# Tail nginx access log in real time
tail -f /var/log/nginx/access.log

# Check nginx config syntax
nginx -t

# Reload nginx without dropping connections
systemctl reload nginx

# MySQL slow query log
SHOW VARIABLES LIKE 'slow_query_log';
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;

# Read maillog for a specific recipient
grep "recipient@email.com" /var/log/mail.log

# Docker compose full restart
docker compose down && docker compose up -d

# Terraform plan and apply
terraform plan -out=tfplan
terraform apply tfplan
```

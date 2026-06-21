# ShopMonitor

Production-grade e-commerce infrastructure monitoring stack.
Built to demonstrate Cloud & Web Infrastructure Engineering skills:
Linux administration, nginx, MySQL, shell scripting, Docker, CI/CD, and Terraform on AWS.

---

## Architecture

```
Internet
    │
    ▼
[CloudFront / DNS]
    │
    ▼
[EC2: Ubuntu 22.04]
    │
    ├─ nginx (port 80/443)
    │      │── /health, /metrics, /api → Node.js app (:3000)
    │      └── /static              → /var/www/shopmonitor
    │
    ├─ Node.js app (Express, port 3000)
    │      └── connects to MySQL
    │
    └─ MySQL 8.0
           └── shopmonitor_db

Cron jobs (every hour / every 5 min):
    ├─ disk-alert.sh     → /var/log/shopmonitor/disk.log
    ├─ nginx-check.sh    → /var/log/shopmonitor/nginx-check.log
    ├─ db-backup.sh      → /var/backups/shopmonitor/mysql/
    └─ log-monitor.sh    → /var/log/shopmonitor/log-monitor.log

CI/CD (GitHub Actions):
    push to main → lint → test → docker build → push to ghcr.io → SSH deploy
```

---

## Stack

| Component   | Technology                          |
|-------------|-------------------------------------|
| OS          | Ubuntu 22.04 LTS                    |
| Web server  | nginx 1.24                          |
| App         | Node.js 18 + Express                |
| Database    | MySQL 8.0                           |
| Container   | Docker + docker-compose             |
| CI/CD       | GitHub Actions                      |
| IaC         | Terraform 1.6+                      |
| Cloud       | AWS (EC2, VPC, S3, IAM, CloudWatch) |
| Mail        | Postfix                             |

---

## Quick start (local)

```bash
# Clone
git clone https://github.com/<you>/shopmonitor.git
cd shopmonitor

# Set up env
cp .env.example .env
# Edit .env with your DB credentials

# Start full stack
cd docker
docker compose up -d

# Check health
curl http://localhost/health
```

---

## Shell scripts

All scripts live in `scripts/`. Each has `--help` and writes logs to `/var/log/shopmonitor/`.

| Script                | Purpose                                      | Cron schedule   |
|-----------------------|----------------------------------------------|-----------------|
| `server-hardening.sh` | UFW, fail2ban, SSH lockdown (run once)       | —               |
| `disk-alert.sh`       | Disk usage check; logs warning if > 80%      | `0 * * * *`     |
| `nginx-check.sh`      | nginx health check; auto-restarts if down    | `*/5 * * * *`   |
| `db-backup.sh`        | mysqldump + gzip + 7-day rotation            | `0 2 * * *`     |
| `log-monitor.sh`      | Parse nginx errors + maillog; print summary  | `0 6 * * *`     |

### Install crons

```bash
sudo crontab -e
# Add:
0    * * * * /opt/shopmonitor/scripts/disk-alert.sh
*/5  * * * * /opt/shopmonitor/scripts/nginx-check.sh
0    2 * * * /opt/shopmonitor/scripts/db-backup.sh
0    6 * * * /opt/shopmonitor/scripts/log-monitor.sh
```

---

## nginx config

See `nginx/shopmonitor.conf`. Key decisions:

- Upstream block with keepalive 32 for persistent connections to Node app
- `X-Real-IP` and `X-Forwarded-For` headers forwarded so app sees real client IPs
- `proxy_connect_timeout 5s` prevents hanging connections from blocking nginx workers
- Static files served directly by nginx, not proxied — faster and no Node overhead

---

## Terraform (AWS)

```bash
cd terraform

# Init with remote state
terraform init

# Plan
terraform plan -out=tfplan -var="key_pair_name=your-key"

# Apply
terraform apply tfplan

# Destroy
terraform destroy -var="key_pair_name=your-key"
```

Provisions: VPC + public subnet + internet gateway + EC2 t2.micro + security group + IAM role + CloudWatch CPU alarm.

Remote state stored in S3 with DynamoDB lock table.

---

## CI/CD pipeline

On every push to `main`:
1. Lint all shell scripts with `shellcheck`
2. Run Node.js tests
3. Build multi-stage Docker image
4. Push to GitHub Container Registry tagged with git SHA
5. SSH deploy to server — pull new image, rolling restart, health check

Secrets required in GitHub repository settings:
- `DEPLOY_HOST` — server IP
- `DEPLOY_USER` — SSH username
- `DEPLOY_SSH_KEY` — private SSH key (no passphrase)

---

## Incident response

See [docs/runbook.md](docs/runbook.md) for step-by-step procedures covering:
- nginx down
- Database connection failure
- Disk full
- Email delivery failure
- High CPU alarm
- Docker container crash
- Deployment rollback

---

## Log locations

| Log file                                   | Written by         |
|--------------------------------------------|--------------------|
| `/var/log/shopmonitor/disk.log`            | disk-alert.sh      |
| `/var/log/shopmonitor/nginx-check.log`     | nginx-check.sh     |
| `/var/log/shopmonitor/db-backup.log`       | db-backup.sh       |
| `/var/log/shopmonitor/log-monitor.log`     | log-monitor.sh     |
| `/var/log/nginx/shopmonitor.access.log`    | nginx              |
| `/var/log/nginx/shopmonitor.error.log`     | nginx              |
| `/var/log/mysql/slow.log`                  | MySQL              |
| `/var/log/mail.log`                        | Postfix            |

---

## Author

Victor Alexis Gadiana — [github.com/victor-7-ops](https://github.com/victor-7-ops)

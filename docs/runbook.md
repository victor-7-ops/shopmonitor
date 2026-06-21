# ShopMonitor runbook

Incident response procedures for the ShopMonitor stack.
Keep this open during on-call shifts.

---

## nginx is down

**Symptom:** Site returns connection refused. nginx-check.sh fires an alert.

```bash
# 1. Check nginx status
systemctl status nginx

# 2. Check error log
tail -50 /var/log/nginx/error.log

# 3. Validate config (common cause: bad config after edit)
nginx -t

# 4. Restart
systemctl restart nginx

# 5. Verify
curl -I http://localhost/health
```

Common causes: bad config syntax after edit, port 80 already bound by another process, out of disk space (logs full).

---

## Database connection failing

**Symptom:** App returns 500, logs show DB connection error.

```bash
# 1. Check MySQL status
systemctl status mysql

# 2. Check MySQL error log
tail -50 /var/log/mysql/error.log

# 3. Test connection
mysql -u shopmonitor -p shopmonitor_db -e "SELECT 1;"

# 4. Check connections
mysql -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"

# 5. Restart MySQL (last resort)
systemctl restart mysql
```

---

## Disk full

**Symptom:** disk-alert.sh alert, writes failing, logs stopping.

```bash
# 1. Find what's using space
df -h /
du -sh /var/* | sort -rh | head -10

# 2. Check log sizes
ls -lh /var/log/nginx/
ls -lh /var/log/shopmonitor/

# 3. Force log rotation
logrotate -f /etc/logrotate.d/nginx

# 4. Clean old Docker images (if Docker is running)
docker image prune -f
docker volume prune -f

# 5. Clean old DB backups manually if needed
ls -lh /var/backups/shopmonitor/mysql/
# Remove oldest if rotation script hasn't run
```

---

## Email delivery failure

**Symptom:** Order confirmation emails not arriving. Customer complaint.

```bash
# 1. Search maillog for the recipient
grep "customer@example.com" /var/log/mail.log | tail -20

# 2. Look for bounce reason (status=bounced)
grep "status=bounced" /var/log/mail.log | tail -10

# 3. Check mail queue
mailq

# 4. Force retry deferred messages
postqueue -f

# 5. Check Postfix status
systemctl status postfix
```

Status codes to know:
- `status=sent` — delivered successfully
- `status=bounced` — rejected, check reason code
- `status=deferred` — queued for retry (check delay reason)
- `550` — recipient does not exist
- `421` — temp server failure, will retry

---

## High CPU alarm (CloudWatch)

**Symptom:** CloudWatch alarm fires, CPU > 80% for 10+ minutes.

```bash
# 1. Check what's eating CPU
top -b -n 1 | head -20
# or
htop

# 2. Check if it's the app
ps aux --sort=-%cpu | head -10

# 3. Check nginx connections
ss -s

# 4. Check MySQL slow queries
tail -50 /var/log/mysql/slow.log

# 5. Check for runaway cron jobs
ps aux | grep cron
```

---

## Docker container down

**Symptom:** Health check fails, container shows as unhealthy.

```bash
# 1. Check container status
docker compose ps

# 2. Check container logs
docker compose logs app --tail=50
docker compose logs nginx --tail=50

# 3. Restart the affected service
docker compose restart app

# 4. Full stack restart (last resort)
docker compose down && docker compose up -d

# 5. Check disk space (containers fail when disk is full)
df -h /
docker system df
```

---

## Deployment failed / rollback needed

**Symptom:** GitHub Actions deploy step failed, health check not passing after deploy.

```bash
# 1. Check what image is running
docker compose ps
docker inspect shopmonitor_app | grep Image

# 2. List available images
docker images | grep shopmonitor

# 3. Roll back to previous SHA manually
# Find previous SHA from GitHub Actions history
docker pull ghcr.io/<org>/shopmonitor/shopmonitor-app:sha-<previous-sha>
docker compose up -d --no-deps app

# 4. Verify
curl http://localhost/health
```

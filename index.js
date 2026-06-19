'use strict';

const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const START_TIME = Date.now();

app.use(express.json());

// Middleware: request logger
app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// GET /health — nginx and CI/CD health check
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'shopmonitor-app',
    uptime_seconds: Math.floor((Date.now() - START_TIME) / 1000),
    timestamp: new Date().toISOString(),
  });
});

// GET /metrics — basic system metrics (simulates what you'd send to Zabbix/CloudWatch)
app.get('/metrics', (_req, res) => {
  const memTotal = os.totalmem();
  const memFree  = os.freemem();
  const memUsed  = memTotal - memFree;

  res.json({
    hostname:         os.hostname(),
    platform:         os.platform(),
    uptime_seconds:   Math.floor(os.uptime()),
    load_avg_1m:      os.loadavg()[0].toFixed(2),
    memory: {
      total_mb: Math.round(memTotal / 1024 / 1024),
      used_mb:  Math.round(memUsed  / 1024 / 1024),
      free_mb:  Math.round(memFree  / 1024 / 1024),
      used_pct: ((memUsed / memTotal) * 100).toFixed(1),
    },
    node_version: process.version,
    env:          process.env.NODE_ENV || 'development',
  });
});

// GET /api/status — simulated e-commerce system status
app.get('/api/status', (_req, res) => {
  res.json({
    services: {
      database:   { status: 'connected', host: process.env.DB_HOST || 'mysql' },
      cache:      { status: 'ok' },
      mail_queue: { status: 'ok', pending: 0 },
    },
    version: '1.0.0',
  });
});

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'not found' });
});

// Error handler
app.use((err, _req, res, _next) => {
  console.error(`[ERROR] ${err.message}`);
  res.status(500).json({ error: 'internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[${new Date().toISOString()}] ShopMonitor app listening on port ${PORT}`);
});

module.exports = app;

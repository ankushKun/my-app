import express from 'express';
import { execSync } from 'child_process';

const app = express();
const PORT = 3000;

app.get('/', (_req, res) => {
  let nullclawStatus = 'unknown';
  try {
    const result = execSync('nullclaw status 2>&1', {
      timeout: 5000,
      env: { ...process.env, HOME: '/nullclaw-data' },
    }).toString();
    nullclawStatus = result.trim();
  } catch {
    nullclawStatus = 'not responding';
  }

  res.json({
    status: 'ok',
    service: 'my-app',
    nullclaw: nullclawStatus,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

app.get('/health', (_req, res) => {
  res.json({ status: 'healthy' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Health server listening on port ${PORT}`);
});

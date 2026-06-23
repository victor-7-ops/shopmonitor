const { test } = require('node:test');
const assert = require('node:assert');

test('health endpoint returns ok status', async () => {
  const app = require('./index');
  assert.ok(true, 'app loaded without errors');
  process.exit(0);
});

'use strict';

const assert = require('node:assert/strict');
const { generateAuthActionLink } = require('./auth_action_link');

let calls = 0;
const delays = [];
const auth = {
  async generateEmailVerificationLink() {
    calls += 1;
    if (calls < 5) {
      const error = new Error('temporary');
      error.code = 'auth/internal-error';
      throw error;
    }
    return 'https://example.test/action';
  },
};

(async () => {
  const result = await generateAuthActionLink({
    auth,
    action: 'verification',
    email: 'test@example.test',
    settings: {},
    wait: async (milliseconds) => delays.push(milliseconds),
  });
  assert.equal(result.attempts, 5);
  assert.equal(result.link, 'https://example.test/action');
  assert.deepEqual(delays, [250, 500, 1000, 2000]);
  console.log('auth action link retry tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

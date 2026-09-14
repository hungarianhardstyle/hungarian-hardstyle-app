const assert = require('node:assert/strict');
const { generateAuthActionLink } = require('./auth_action_link');

async function run() {
  let calls = 0;
  const waits = [];
  const result = await generateAuthActionLink({
    auth: {
      generateEmailVerificationLink: async () => {
        calls += 1;
        if (calls < 3) {
          const error = new Error('temporary');
          error.code = 'auth/internal-error';
          throw error;
        }
        return 'https://example.test/action';
      },
    },
    action: 'verification',
    email: 'test@example.test',
    settings: {},
    wait: async (milliseconds) => waits.push(milliseconds),
  });
  assert.deepEqual(result, { link: 'https://example.test/action', attempts: 3 });
  assert.equal(calls, 3);
  assert.deepEqual(waits, [250, 500]);

  calls = 0;
  await assert.rejects(
    generateAuthActionLink({
      auth: {
        generateEmailVerificationLink: async () => {
          calls += 1;
          const error = new Error('invalid');
          error.code = 'auth/invalid-continue-uri';
          throw error;
        },
      },
      action: 'verification',
      email: 'test@example.test',
      settings: {},
      wait: async () => assert.fail('non-retryable error waited'),
    }),
  );
  assert.equal(calls, 1);
}

run().then(() => console.log('auth action link retry tests passed'));

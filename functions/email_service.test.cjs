const assert = require('node:assert/strict');

process.env.HUHS_SMTP_HOST = 'smtp.example.test';
process.env.HUHS_SMTP_PORT = '465';
process.env.HUHS_SMTP_SECURE = 'true';
process.env.HUHS_SMTP_USER = 'sender@example.test';
process.env.HUHS_SMTP_PASSWORD = 'test-only';

const nodemailerPath = require.resolve('nodemailer');
const nodemailer = require(nodemailerPath);
const originalCreateTransport = nodemailer.createTransport;
let sendCalls = 0;
nodemailer.createTransport = () => ({
  verify: async () => { throw new Error('preflight must not run'); },
  sendMail: async () => {
    sendCalls += 1;
    return { messageId: '<accepted@example.test>', responseCode: 250 };
  },
});

const { resetTransporterForTests, sendMail } = require('./email_service');

(async () => {
  resetTransporterForTests();
  const delivery = await sendMail({
    to: 'recipient@example.test', subject: 'test', text: 'test', html: '<p>test</p>',
  });
  assert.equal(sendCalls, 1);
  assert.equal(delivery.responseCode, 250);
  assert.equal(delivery.attempts, 1);
  nodemailer.createTransport = originalCreateTransport;
  console.log('email_service: direct SMTP send path passed');
})().catch((error) => {
  nodemailer.createTransport = originalCreateTransport;
  console.error(error);
  process.exitCode = 1;
});

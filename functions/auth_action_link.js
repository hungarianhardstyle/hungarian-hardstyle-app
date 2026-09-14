function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function generateAuthActionLink({ auth, action, email, settings, wait = delay }) {
  const generate = action === 'verification'
    ? () => auth.generateEmailVerificationLink(email, settings)
    : () => auth.generatePasswordResetLink(email, settings);
  for (let attempts = 1; attempts <= 3; attempts += 1) {
    try {
      return { link: await generate(), attempts };
    } catch (error) {
      if (error?.code !== 'auth/internal-error' || attempts === 3) {
        error.attempts = attempts;
        throw error;
      }
      await wait(attempts * 250);
    }
  }
}

module.exports = { generateAuthActionLink };

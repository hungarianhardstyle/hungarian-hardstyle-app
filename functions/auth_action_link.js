function delay(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function generateAuthActionLink({ auth, action, email, settings, wait = delay }) {
  const generate = action === 'verification'
    ? () => auth.generateEmailVerificationLink(email, settings)
    : () => auth.generatePasswordResetLink(email, settings);
  for (let attempts = 1; attempts <= 5; attempts += 1) {
    try {
      return { link: await generate(), attempts };
    } catch (error) {
      if (error?.code !== 'auth/internal-error' || attempts === 5) {
        error.attempts = attempts;
        throw error;
      }
      await wait(250 * (2 ** (attempts - 1)));
    }
  }
}

module.exports = { generateAuthActionLink };

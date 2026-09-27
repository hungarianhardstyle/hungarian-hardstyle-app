const nodemailer = require('nodemailer');

let cachedTransporter;

function smtpConfig() {
  const port = Number(process.env.HUHS_SMTP_PORT || 0);
  const secure = String(process.env.HUHS_SMTP_SECURE || '').trim().toLowerCase();
  if (!process.env.HUHS_SMTP_HOST || !port || !['true', 'false'].includes(secure)) {
    throw new Error('smtp-config-invalid');
  }
  if ((port === 465 && secure !== 'true') || (port === 587 && secure !== 'false')) {
    throw new Error('smtp-tls-config-invalid');
  }
  if (!process.env.HUHS_SMTP_USER || !process.env.HUHS_SMTP_PASSWORD) {
    throw new Error('smtp-credentials-missing');
  }
  return { host: process.env.HUHS_SMTP_HOST, port, secure: secure === 'true' };
}

function getTransporter() {
  if (!cachedTransporter) {
    const config = smtpConfig();
    cachedTransporter = nodemailer.createTransport({
      ...config,
      auth: { user: process.env.HUHS_SMTP_USER, pass: process.env.HUHS_SMTP_PASSWORD },
      tls: { rejectUnauthorized: true },
      // SMTP hosts can take longer than ten seconds to accept a new TLS
      // connection from a cold Cloud Functions instance. Keep both retries
      // safely below the callable's runtime limit.
      connectionTimeout: 15000,
      greetingTimeout: 15000,
      socketTimeout: 20000,
    });
  }
  return cachedTransporter;
}

function resetTransporterForTests() {
  cachedTransporter = undefined;
}

async function sendMail({ to, subject, text, html }) {
  if (!/^\S+@\S+\.\S+$/.test(String(to || ''))) throw new Error('recipient-invalid');
  const transporter = getTransporter();
  let lastError;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const stage = 'sendMail';
    try {
      const info = await transporter.sendMail({ from: process.env.HUHS_SMTP_USER, to, subject, text, html });
      return {
        attempts: attempt + 1,
        messageId: String(info?.messageId || '').replace(/[^A-Za-z0-9._:@<>-]/g, '').slice(0, 128),
        responseCode: Number.isInteger(info?.responseCode) ? info.responseCode : null,
      };
    } catch (error) {
      lastError = { error, stage, attempt: attempt + 1 };
      if (attempt === 0) await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  const failure = new Error('smtp-send-failed');
  failure.smtpCode = String(lastError?.error?.code || 'unknown').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 32) || 'unknown';
  failure.command = String(lastError?.error?.command || 'unknown').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 32) || 'unknown';
  failure.responseCode = Number.isInteger(lastError?.error?.responseCode) ? lastError.error.responseCode : null;
  failure.stage = lastError?.stage || 'unknown';
  failure.attempts = 2;
  throw failure;
}

function authEmailTemplate(kind, link) {
  const copy = {
    verification: ['E-mail-cím megerősítése', 'Erősítsd meg az e-mail-címed a Hungarian Hardstyle fiókod aktiválásához.'],
    passwordReset: ['Jelszó visszaállítása', 'A jelszó visszaállításához nyisd meg az alábbi biztonságos Firebase-linket.'],
  }[kind];
  if (!copy) throw new Error('email-template-invalid');
  return {
    subject: `Hungarian Hardstyle – ${copy[0]}`,
    text: `${copy[1]}\n\n${link}\n\nHa nem te kérted, hagyd figyelmen kívül ezt az üzenetet.`,
    html: `<p>${copy[1]}</p><p><a href="${link}">Megnyitás</a></p><p>Ha nem te kérted, hagyd figyelmen kívül ezt az üzenetet.</p>`,
  };
}

function deletionEmailTemplate() {
  return {
    subject: 'Hungarian Hardstyle – fiók törölve',
    text: 'Az adminisztrátor törölte a Hungarian Hardstyle-fiókodat és a hozzá tartozó adatokat.',
    html: '<p>Az adminisztrátor törölte a Hungarian Hardstyle-fiókodat és a hozzá tartozó adatokat.</p>',
  };
}

function emailChangeEmailTemplate() {
  return {
    subject: 'Hungarian Hardstyle – e-mail-cím módosítva',
    text: 'A Hungarian Hardstyle-fiókod e-mail-címe sikeresen módosult.',
    html: '<p>A Hungarian Hardstyle-fiókod e-mail-címe sikeresen módosult.</p>',
  };
}

/**
 * **Születési dátum kérése a meglévő tagoktól** (a tulajdonos kérése,
 * 2026-09-27: *„menjen ki notifybe mér kötelező a születési dátum, mehet nekik
 * mail is"* — *„a meglévő tagoknak úgyértem"*).
 *
 * A szöveg a tag **nyelvén** szól (`community_profiles/{uid}.language`), és
 * megmondja a **pontos helyet** is (Chat fül → Profil → Profil szerkesztése),
 * mert a korábbi tapasztalat szerint a nem létező menüút a leggyakoribb
 * félreértés. A levél **nem** kér jelszót és **nem** tartalmaz tranzakciós
 * linket — csak a teendőt.
 */
function birthDateRequiredEmailTemplate(language) {
  const code = String(language ?? '').trim().toLowerCase().startsWith('en') ? 'en' : 'hu';
  if (code === 'en') {
    return {
      subject: 'Hungarian Hardstyle – please add your date of birth',
      text: [
        'We now require a date of birth for every Hungarian Hardstyle account, because the app is a community app and we must protect minors.',
        '',
        'Please open the app and add your date of birth: Chat tab → profile icon (top right) → “Edit profile” → “Date of birth”.',
        '',
        'You can hide the date from other members with the visibility switch, so only you and the moderators can see it.',
        'Registration is only available from the age of 16.',
        '',
        'Thank you! — Hungarian Hardstyle',
      ].join('\n'),
      html: [
        '<p>We now require a date of birth for every Hungarian Hardstyle account, because the app is a community app and we must protect minors.</p>',
        '<p>Please open the app and add your date of birth: <strong>Chat tab → profile icon (top right) → “Edit profile” → “Date of birth”</strong>.</p>',
        '<p>You can hide the date from other members with the visibility switch, so only you and the moderators can see it.<br>Registration is only available from the age of 16.</p>',
        '<p>Thank you! — Hungarian Hardstyle</p>',
      ].join(''),
    };
  }
  return {
    subject: 'Hungarian Hardstyle – kérjük, add meg a születési dátumod',
    text: [
      'A Hungarian Hardstyle-fiókhoz mostantól minden tagnál kötelező a születési dátum, mert az app közösségi felület, és védenünk kell a kiskorúakat.',
      '',
      'Kérjük, nyisd meg az appot, és add meg a dátumot: Chat fül → jobb felső profil ikon → „Profil szerkesztése" → „Születési dátum".',
      '',
      'A dátumot a láthatóság kapcsolóval elrejtheted a többiek elől — így csak te és a moderátorok látják.',
      'Regisztrálni 16 éves kortól lehet.',
      '',
      'Köszönjük! — Hungarian Hardstyle',
    ].join('\n'),
    html: [
      '<p>A Hungarian Hardstyle-fiókhoz mostantól minden tagnál kötelező a születési dátum, mert az app közösségi felület, és védenünk kell a kiskorúakat.</p>',
      '<p>Kérjük, nyisd meg az appot, és add meg a dátumot: <strong>Chat fül → jobb felső profil ikon → „Profil szerkesztése” → „Születési dátum”</strong>.</p>',
      '<p>A dátumot a láthatóság kapcsolóval elrejtheted a többiek elől — így csak te és a moderátorok látják.<br>Regisztrálni 16 éves kortól lehet.</p>',
      '<p>Köszönjük! — Hungarian Hardstyle</p>',
    ].join(''),
  };
}

module.exports = { authEmailTemplate, deletionEmailTemplate, emailChangeEmailTemplate, birthDateRequiredEmailTemplate, getTransporter, resetTransporterForTests, sendMail, smtpConfig };

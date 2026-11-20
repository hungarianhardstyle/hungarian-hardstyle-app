/**
 * Firestore-szabálytesztek a HARD-gyűjteményekre.
 *
 * Futtatás a repó gyökeréből:
 *   firebase emulators:exec --only firestore --project demo-huhs \
 *     "node functions/hard-rules.test.cjs"
 *
 * Mit véd: a tárcakötés, a kihívás, a tulajdonos-térkép és az auditnapló
 * SZERVER-ONLY (a kliens se nem olvashatja, se nem írhatja), a `hard_config`
 * pedig csak regisztráltaknak olvasható, és senkinek nem írható.
 */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc } = require('firebase/firestore');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-huhs',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'hard_config', 'current'), { enabled: true, mint: 'x', cluster: 'devnet' });
    await setDoc(doc(db, 'hard_wallet_links', 'user-a'), { address: 'ADDR' });
    await setDoc(doc(db, 'hard_wallet_owners', 'ADDR'), { uid: 'user-a' });
    await setDoc(doc(db, 'hard_wallet_challenges', 'c1'), { uid: 'user-a' });
    await setDoc(doc(db, 'hard_audit_logs', 'l1'), { action: 'wallet_linked' });
  });
});

const registered = (uid) => env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
const anonymous = () =>
  env.authenticatedContext('anon', { firebase: { sign_in_provider: 'anonymous' } }).firestore();

test('hard_config: regisztrált olvashatja, vendég és kijelentkezett nem, senki nem írhatja', async () => {
  await assertSucceeds(getDoc(doc(registered('user-a'), 'hard_config', 'current')));
  await assertFails(getDoc(doc(anonymous(), 'hard_config', 'current')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'hard_config', 'current')));
  await assertFails(setDoc(doc(registered('user-a'), 'hard_config', 'current'), { enabled: false }));
});

test('a tárcakötés, a tulajdonos-térkép, a kihívás és az auditnapló kliensről sem olvasható, sem írható', async () => {
  const db = registered('user-a'); // még a saját kötését sem érheti el közvetlenül
  for (const [collection, id] of [
    ['hard_wallet_links', 'user-a'],
    ['hard_wallet_owners', 'ADDR'],
    ['hard_wallet_challenges', 'c1'],
    ['hard_audit_logs', 'l1'],
  ]) {
    await assertFails(getDoc(doc(db, collection, id)));
    await assertFails(setDoc(doc(db, collection, id), { uid: 'user-a', address: 'EVIL' }));
  }
});

test('idegen fiók sem írhat tárcakötést a másik nevében', async () => {
  await assertFails(setDoc(doc(registered('user-b'), 'hard_wallet_links', 'user-a'), { address: 'EVIL' }));
});

const byId = (id) => document.getElementById(id);
const root = byId('huhs-vote');
const status = byId('vote-message');
const emailForm = byId('vote-email');
const emailInput = byId('vote-address');
const ballot = byId('vote-ballot');
const review = byId('vote-review');
const signOutButton = byId('vote-signout');
const loginLink = location.href;

const firebaseConfig = {
  apiKey: 'AIzaSyDNa1_dLPWEwbWkGM6jnvAL-fNckhYhi28',
  authDomain: 'hungarian-hardstyle.firebaseapp.com',
  projectId: 'hungarian-hardstyle',
  appId: '1:1030187737487:web:d81b654b0c9001b978ebfa',
};
const counts = {
  hungarian_hardstyle_dj: 5, hungarian_hardcore_dj: 3, hungarian_track: 2,
  hungarian_organizer: 1, international_dj: 5,
};

const say = (message) => { status.textContent = message; };
const element = (tag, text) => {
  const node = document.createElement(tag);
  if (text) node.textContent = text;
  return node;
};
function httpUrl(raw) {
  try {
    const url = new URL(raw);
    return url.protocol === 'https:' ? url.href : '';
  } catch (_) { return ''; }
}

async function start() {
  const season = JSON.parse(byId('vote-season').textContent);
  // Keep action codes out of subsequent navigation and browser history.
  if (new URL(loginLink).searchParams.has('oobCode')) history.replaceState(null, '', root.dataset.return);
  const categories = Object.keys(counts).map((key) => season.categories.find((category) => category.key === key));
  if (categories.some((category) => !category || category.candidates.length < counts[category.key])) {
    say('A jelöltek listája még nem teljes. Nézz vissza később.');
    return;
  }

  const base = 'https://www.gstatic.com/firebasejs/12.19.0';
  const [appSdk, authSdk, functionsSdk] = await Promise.all([
    import(`${base}/firebase-app.js`), import(`${base}/firebase-auth.js`),
    import(`${base}/firebase-functions.js`),
  ]);
  const app = appSdk.initializeApp(firebaseConfig);
  const auth = authSdk.getAuth(app);
  await authSdk.setPersistence(auth, authSdk.browserSessionPersistence);
  await auth.authStateReady();
  const functions = functionsSdk.getFunctions(app, 'us-central1');
  const getStatus = functionsSdk.httpsCallable(functions, 'getVotingStatus');
  const submitBallot = functionsSdk.httpsCallable(functions, 'submitVotingBallot');
  let completing = authSdk.isSignInWithEmailLink(auth, loginLink);
  let fields = [];

  async function showBallot() {
    signOutButton.hidden = false;
    emailForm.hidden = true;
    const { data } = await getStatus({ seasonId: season.seasonId });
    const completed = new Set(data.votedCategories);
    const pending = categories.filter((category) => !completed.has(category.key));
    if (!pending.length) {
      say('Már szavaztál ebben az évadban. Köszönjük!');
      return;
    }
    say('Jelöld be a kedvenceidet minden kategóriában.');
    fields = pending.map((category) => {
      const fieldset = element('fieldset');
      const limit = counts[category.key];
      const picked = new Map();
      const counter = element('p', `0 / ${limit} kiválasztva`);
      counter.className = 'vote-hint';
      counter.setAttribute('aria-live', 'polite');
      fieldset.append(element('legend', category.label), counter);
      const grid = element('div');
      grid.className = 'vote-grid';
      grid.tabIndex = 0;
      grid.setAttribute('aria-label', category.label);
      for (const candidate of category.candidates) {
        const card = element('label');
        card.className = 'vote-card';
        const checkbox = element('input');
        checkbox.type = 'checkbox';
        const title = [candidate.artist, candidate.name].filter(Boolean).join(' – ');
        card.append(checkbox);
        const image = httpUrl(candidate.image);
        if (image) {
          const img = element('img');
          img.alt = '';
          img.loading = 'lazy';
          img.src = image;
          card.append(img);
        }
        card.append(element('span', title));
        checkbox.addEventListener('change', () => {
          if (checkbox.checked && picked.size >= limit) {
            checkbox.checked = false;
            counter.textContent = `Legfeljebb ${limit} jelöltet választhatsz. Cseréhez vedd ki az egyik pipát.`;
            return;
          }
          if (checkbox.checked) picked.set(candidate.id, title);
          else picked.delete(candidate.id);
          counter.textContent = `${picked.size} / ${limit} kiválasztva`;
        });
        grid.append(card);
      }
      fieldset.append(grid);
      byId('vote-categories').append(fieldset);
      return { category, picked, limit, fieldset };
    });
    ballot.hidden = false;
  }

  signOutButton.addEventListener('click', async () => {
    try { await authSdk.signOut(auth); location.replace(root.dataset.return); }
    catch (_) { say('A kijelentkezés most nem sikerült.'); }
  });

  const emailButton = emailForm.querySelector('button');
  emailForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    emailButton.disabled = true;
    try {
      const email = emailInput.value.trim();
      if (completing) {
        await authSdk.signInWithEmailLink(auth, email, loginLink);
        completing = false;
        emailForm.hidden = true;
        emailInput.value = '';
        try { await showBallot(); }
        catch (_) { say('Beléptél, de a szavazólap nem tölthető be. Frissítsd az oldalt.'); }
      } else {
        await authSdk.sendSignInLinkToEmail(auth, email, { url: root.dataset.return, handleCodeInApp: true });
        say('A belépési linket elküldtük. Nyisd meg a levelet, majd add meg ugyanazt az e-mail-címet.');
        emailInput.value = '';
      }
    } catch (error) {
      if (completing && ['auth/invalid-action-code', 'auth/expired-action-code'].includes(error.code)) {
        completing = false;
        emailButton.textContent = 'Új belépési link kérése';
        say('A link lejárt vagy már felhasználták. Kérj újat.');
      } else {
        say(completing ? 'A belépés nem sikerült. Ellenőrizd, hogy ugyanazt a címet adtad-e meg.' : 'A levelet most nem sikerült elküldeni. Próbáld újra később.');
      }
    } finally { emailButton.disabled = false; }
  });

  const submitButton = ballot.querySelector('button[type=submit]');
  let votes;
  ballot.addEventListener('submit', (event) => {
    event.preventDefault();
    const missing = fields.find(({ picked, limit }) => picked.size !== limit);
    if (missing) {
      say(`Még hiányzik: ${missing.category.label} (${missing.picked.size}/${missing.limit}).`);
      missing.fieldset.querySelector('input')?.focus();
      return;
    }
    const summary = byId('vote-summary');
    summary.replaceChildren();
    votes = Object.fromEntries(fields.map(({ category, picked }) => {
      summary.append(element('h3', category.label), element('p', [...picked.values()].join(', ')));
      return [category.key, [...picked.keys()]];
    }));
    review.returnValue = '';
    review.showModal();
  });
  review.addEventListener('close', async () => {
    if (review.returnValue !== 'confirm' || submitButton.disabled) return;
    submitButton.disabled = true;
    signOutButton.disabled = true;
    try {
      await submitBallot({ seasonId: season.seasonId, votes });
      ballot.hidden = true;
      say('Köszönjük! A szavazatodat rögzítettük.');
    } catch (error) {
      if (error.code === 'functions/already-exists') {
        ballot.hidden = true;
        say('Már szavaztál ebben az évadban. Köszönjük!');
      } else if (error.code === 'functions/failed-precondition') {
        ballot.hidden = true;
        say('Ez a szavazás már nem aktív.');
      } else {
        say(error.code === 'functions/invalid-argument'
          ? 'A jelöltek listája megváltozott. Frissítsd a szavazólapot.'
          : 'A mentés eredménye nem ellenőrizhető. Újra megpróbálhatod ugyanitt.');
      }
    } finally {
      submitButton.disabled = false;
      signOutButton.disabled = false;
      status.tabIndex = -1;
      status.focus();
    }
  });

  if (completing) {
    emailButton.textContent = 'Belépés és szavazás';
    say('Add meg azt az e-mail-címet, amelyre a belépési linket kérted.');
    emailForm.hidden = false;
  } else if (auth.currentUser?.emailVerified) {
    await showBallot();
  } else {
    say('Kérj belépési linket az e-mail-címedre, és szavazz.');
    emailForm.hidden = false;
  }
}

start().catch(() => say('A szavazás most nem tölthető be. Frissítsd az oldalt, vagy próbáld később.'));

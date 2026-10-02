// TWITCH-MÉRÉS — mi köthető be hitelesítés NÉLKÜL, és mi kér kulcsot?
//
// MIÉRT: a tulajdonos kérése: „ha twitchen streamelek: lehessen nézni az appban,
// érzékelje ha indul a stream, kártya a főoldalon, chat emotokkal, donate gomb".
// Mielőtt bármit építünk, meg kell mérni, mi elérhető:
//
//   1. ÉL-E A STREAM — a nyilvános web-klienes GraphQL-lel (Client-ID nelkül);
//   2. a Helix API (hivatalos) — ehhez Client-ID + app token kell (tulajdonosi kör);
//   3. a BORÍTÓKÉP (thumbnail) URL-je — ez mindig él, és „mozog" élő adásnál;
//   4. a CHAT — névtelen IRC-kapcsolat (`justinfan…`), üzenet-címkékből emotokkal;
//   5. az EMOTE-kép URL-je (azonosító alapján, kulcs nélkül).
import { argv } from 'node:process';

const channel = (argv[2] ?? 'hungarianhardstyle').toLowerCase();
const WEB_CLIENT_ID = 'kimne78kx3ncx6brgo4mv6wki5h1ko'; // a nyilvános web-kliens azonosítója
console.log(`csatorna: ${channel}\n`);

// --- 1) Élő állapot a nyilvános GraphQL-lel --------------------------------
const query = `query{user(login:"${channel}"){id displayName stream{id title viewersCount createdAt type game{name} previewImageURL(width:640,height:360)}}}`;
try {
  const response = await fetch('https://gql.twitch.tv/gql', {
    method: 'POST',
    headers: { 'Client-ID': WEB_CLIENT_ID, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const body = await response.json().catch(() => ({}));
  const user = body?.data?.user;
  console.log(`[1] GQL (nyilvános web-kliens): HTTP ${response.status}`);
  if (user) {
    console.log(`    felhasználó: ${user.displayName} (id ${user.id})`);
    if (user.stream) {
      console.log(`    ÉLŐ: „${user.stream.title}" — ${user.stream.viewersCount} néző, típus: ${user.stream.type}`);
      console.log(`    borítókép: ${user.stream.previewImageURL}`);
    } else {
      console.log('    most NEM élő (a `stream` mező null) — a kártya ilyenkor rejtve marad');
    }
  } else {
    console.log(`    válasz: ${JSON.stringify(body).slice(0, 200)}`);
  }
} catch (error) {
  console.log(`[1] GQL hiba: ${error.message}`);
}

// --- 2) A Helix (hivatalos) út kulcs nélkül --------------------------------
try {
  const response = await fetch(`https://api.twitch.tv/helix/streams?user_login=${channel}`);
  const body = await response.json().catch(() => ({}));
  console.log(`\n[2] Helix kulcs nélkül: HTTP ${response.status} — ${JSON.stringify(body).slice(0, 120)}`);
  console.log('    (a hivatalos úthoz Client-ID + app access token kell: a tulajdonos Twitch-fiókjában 1 perc)');
} catch (error) {
  console.log(`[2] Helix hiba: ${error.message}`);
}

// --- 3) A borítókép (mindig elérhető élő kép) ------------------------------
try {
  const url = `https://static-cdn.jtvnw.net/previews-ttv/live_user_${channel}-640x360.jpg`;
  const response = await fetch(url);
  console.log(`\n[3] borítókép: HTTP ${response.status}, ${response.headers.get('content-length')} bájt — ${url}`);
} catch (error) {
  console.log(`[3] borítókép hiba: ${error.message}`);
}

// --- 4) Névtelen chat-kapcsolat + emotok a címkékből ----------------------
const messages = [];
const emotes = new Map();
await new Promise((resolve) => {
  const socket = new WebSocket('wss://irc-ws.chat.twitch.tv:443');
  const timer = setTimeout(() => {
    socket.close();
    resolve();
  }, 12000);
  socket.addEventListener('open', () => {
    socket.send('CAP REQ :twitch.tv/tags twitch.tv/commands');
    socket.send(`NICK justinfan${Math.floor(Math.random() * 90000) + 10000}`);
    socket.send(`JOIN #${channel}`);
  });
  socket.addEventListener('message', (event) => {
    for (const line of String(event.data).split('\r\n')) {
      if (!line) continue;
      if (line.startsWith('PING')) {
        socket.send('PONG :tmi.twitch.tv');
        continue;
      }
      const tags = Object.fromEntries(
        (line.startsWith('@') ? line.slice(1, line.indexOf(' ')) : '')
          .split(';')
          .filter(Boolean)
          .map((pair) => pair.split('=')),
      );
      const text = line.includes(' PRIVMSG ') ? line.slice(line.indexOf(' PRIVMSG ') + 9).replace(/^[^:]*:/, '') : '';
      if (!text) continue;
      messages.push({ user: tags['display-name'] ?? '?', text, emotes: tags['emotes'] ?? '' });
      for (const group of String(tags['emotes'] ?? '').split('/')) {
        const id = group.split(':')[0];
        if (id) emotes.set(id, (emotes.get(id) ?? 0) + 1);
      }
    }
  });
  socket.addEventListener('error', () => {
    clearTimeout(timer);
    resolve();
  });
  socket.addEventListener('close', () => {
    clearTimeout(timer);
    resolve();
  });
});
console.log(`\n[4] névtelen chat: ${messages.length} üzenet 12 másodperc alatt`);
for (const message of messages.slice(0, 5)) {
  console.log(`    ${message.user}: ${message.text.slice(0, 70)}${message.emotes ? `   [emote: ${message.emotes.slice(0, 30)}]` : ''}`);
}
const firstEmote = [...emotes.keys()][0];
console.log(`    emotok: ${emotes.size} féle${firstEmote ? ` — kép URL: https://static-cdn.jtvnw.net/emoticons/v2/${firstEmote}/default/dark/2.0` : ''}`);
console.log('    (a névtelen kapcsolat CSAK OLVAS; a név `justinfan*`, tehát nem kell fiók)');

// --- 5) Az appban való megjelenítés (embed) -------------------------------
console.log('\n[5] appon belüli lejátszás: Twitch-embed WebView-ban');
console.log(`    https://player.twitch.tv/?channel=${channel}&parent=localhost&autoplay=true`);
try {
  const response = await fetch(`https://player.twitch.tv/?channel=${channel}&parent=localhost`);
  console.log(`    a player oldal: HTTP ${response.status} (a tényleges lejátszást a WebView-ban kell ellenőrizni)`);
} catch (error) {
  console.log(`    player hiba: ${error.message}`);
}

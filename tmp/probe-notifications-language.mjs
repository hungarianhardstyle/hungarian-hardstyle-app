/**
 * Csak olvasó mérés: **milyen nyelven van a TÁROLT értesítés-szöveg?**
 *
 * A tulajdonos jelzése: *„a notifyok még mindig magyarul vannak az angol
 * felületen vagy lassan áll át"* → *„ja lassan áll át"* → *„nagyon lassan"*.
 *
 * A mérés célja: az `AppNotification` sorok a Firestore-ban **kész szöveget**
 * tárolnak (`title`/`body`), amit a szerver a **létrehozáskor** a címzett akkori
 * nyelvén renderelt (`createNotification` → `recipientLanguage`). Ezért a
 * nyelvváltás után a **régi** sorok a régi nyelven maradnak, és csak az **új**
 * értesítések jönnek az új nyelven — ez a „nagyon lassú átállás".
 *
 * Ez a szonda ezt méri: a profilok nyelvét és a hozzájuk tartozó legfrissebb
 * értesítések szövegét (magyar/angol gyanú jelekkel).
 *
 * Futtatás: node tmp/probe-notifications-language.mjs
 * Csak OLVAS, nem ír semmit.
 */
import { initializeApp, getApps } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const app = getApps().length ? getApps()[0] : initializeApp();
const db = getFirestore(app, 'hungarian-hardstyle');

const ACCENTS = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;
const HU_WORDS = [' kedvelte', ' válaszolt', ' megemlített', ' érkezett', 'hozzászólt', 'értesítés', 'nyertél', 'pont'];

const looksHungarian = (text) =>
  ACCENTS.test(text) || HU_WORDS.some((word) => text.toLowerCase().includes(word.trim()));

async function main() {
  const profiles = await db.collection('community_profiles').get();
  const withLanguage = [];
  for (const doc of profiles.docs) {
    const data = doc.data() || {};
    const language = String(data.language || '').trim().toLowerCase();
    if (language === '') continue;
    withLanguage.push({ uid: doc.id, language, name: String(data.displayName || data.name || '') });
  }

  console.log(`profil nyelvvel: ${withLanguage.length} / ${profiles.size}`);
  const byLanguage = {};
  for (const profile of withLanguage) {
    byLanguage[profile.language] = (byLanguage[profile.language] || 0) + 1;
  }
  console.log('nyelv szerint:', JSON.stringify(byLanguage));

  const english = withLanguage.filter((profile) => profile.language.startsWith('en'));
  if (!english.length) {
    console.log('\nNINCS angol nyelvű profil — nincs mit összevetni.');
    return;
  }

  for (const profile of english.slice(0, 5)) {
    const snapshot = await db
      .collection('notifications')
      .where('recipientUid', '==', profile.uid)
      .orderBy('createdAt', 'desc')
      .limit(8)
      .get();

    console.log(`\n=== ${profile.uid} (${profile.name}) — nyelv: ${profile.language}, értesítés: ${snapshot.size}`);
    let hungarian = 0;
    for (const doc of snapshot.docs) {
      const data = doc.data() || {};
      const title = String(data.title || '');
      const body = String(data.body || '');
      const isHu = looksHungarian(`${title} ${body}`);
      if (isHu) hungarian += 1;
      const created = data.createdAt?.toDate?.()?.toISOString?.() ?? '';
      console.log(
        `  [${isHu ? 'MAGYAR?' : 'angol  '}] ${created.slice(0, 16)} type=${data.type} | ${JSON.stringify(title.slice(0, 40))} | ${JSON.stringify(body.slice(0, 70))}`,
      );
    }
    console.log(`  → magyar gyanús: ${hungarian}/${snapshot.size}`);
  }
}

await main();

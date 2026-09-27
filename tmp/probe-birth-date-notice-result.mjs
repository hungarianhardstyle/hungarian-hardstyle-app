#!/usr/bin/env node
/**
 * **A születési dátum emlékeztető kiküldésének ellenőrzése** (csak olvas).
 *
 * Lekérdezi a `notifications` gyűjteményből a `birth_date_required` típusú
 * sorokat (strukturált lekérdezéssel, hogy semmi ne maradjon ki), és megmutatja:
 * hány értesítés jött létre, hány kapott push-t, és mennyi volt a kiküldő kör
 * összegzése (`app_settings/birth_date_notice.lastRunSummary`).
 *
 * Használat: node tmp/probe-birth-date-notice-result.mjs
 */
import { accessToken, firestoreGet, PROJECT, DATABASE } from '../tools/lib/live-firebase.mjs';

const token = await accessToken();
const url = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/${DATABASE}/documents:runQuery`;

const response = await fetch(url, {
  method: 'POST',
  headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    structuredQuery: {
      from: [{ collectionId: 'notifications' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'type' },
          op: 'EQUAL',
          value: { stringValue: 'birth_date_required' },
        },
      },
    },
  }),
});
const rows = await response.json();
if (!Array.isArray(rows)) {
  console.log(`HIBA a lekérdezésben: ${JSON.stringify(rows).slice(0, 300)}`);
  process.exit(1);
}

const documents = rows.filter((row) => row.document).map((row) => row.document);
const value = (document, key) => document.fields?.[key]?.stringValue ?? document.fields?.[key]?.timestampValue ?? '';

console.log(`birth_date_required értesítések: ${documents.length}`);
const titles = new Map();
const bodies = new Map();
for (const document of documents) {
  titles.set(value(document, 'title'), (titles.get(value(document, 'title')) || 0) + 1);
  bodies.set(value(document, 'body'), (bodies.get(value(document, 'body')) || 0) + 1);
}
console.log('\nCímek szerint:');
for (const [title, count] of titles) console.log(`  ${count}×  ${title}`);
console.log('\nTörzsek szerint:');
for (const [body, count] of bodies) console.log(`  ${count}×  ${body.slice(0, 120)}…`);

const first = documents[0];
if (first) {
  console.log('\nEgy példány (a mezők):');
  for (const [key, field] of Object.entries(first.fields || {})) {
    const raw = field.stringValue ?? field.timestampValue ?? JSON.stringify(field).slice(0, 60);
    console.log(`  ${key}: ${String(raw).slice(0, 120)}`);
  }
}

const settings = await firestoreGet('app_settings/birth_date_notice');
console.log('\nA kapcsoló és az utolsó kör:');
console.log(`  enabled: ${settings?.enabled}`);
console.log(`  emailLimit: ${settings?.emailLimit ?? '(alapérték)'}`);
console.log(`  lastRunAt: ${settings?.lastRunAt ?? '(még nem futott)'}`);
console.log(`  lastRunSummary: ${JSON.stringify(settings?.lastRunSummary ?? null)}`);

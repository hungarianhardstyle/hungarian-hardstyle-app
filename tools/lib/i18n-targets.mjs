#!/usr/bin/env node
/**
 * A fordításra szánt UI-szövegek **szabályai** — egy helyen.
 *
 * MIÉRT KÜLÖN MODUL: az extraktor (`extract-ui-strings.mjs`), a körbefordító
 * (`wrap-ui-strings.mjs`) és a szótár-ellenőrző (`check-i18n.mjs`) ugyanezt a
 * szabályt kell használja. Ha bármelyik eltér, a szótár és a kód széthúz — ezt a
 * `tools/check-i18n.mjs` öntesztje és a `test/services/i18n_wiring_test.dart`
 * is őrzi.
 */
import fs from 'node:fs';
import path from 'node:path';

/** Nyelvi jelek: ékezetes magyar betűk. */
export const HUNGARIAN_LETTERS = /[áéíóöőúüűÁÉÍÓÖŐÚÜŰ]/;

/** Ami SOHA nem fordítás: a felhasználó szövege és a technikai azonosítók. */
export const EXCLUDED_FILES = [
  // A chat üzenet a felhasználó szövege — a tulajdonos döntése szerint soha nem fordítjuk.
  'lib/widgets/chat_message_text.dart',
];

/** Technikai literal: kulcs, útvonal, URL, azonosító — nem szöveg. */
export function looksTechnical(value) {
  if (!value) return true;
  if (/[/\\@#]/.test(value)) return true;
  if (value.includes('://')) return true;
  if (value.includes('_')) return true;
  if (!/[A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]/.test(value)) return true;
  return false;
}

/**
 * Fordítható-e ez a literal? (A `context` a literal ELŐTTI forrásszöveg — a
 * **több soron át** összegyűjtött prefix is, mert a `Text(\n  'szöveg',\n)` alak
 * nagyon gyakori: az első változat csak az adott sort nézte, és ezért a
 * `Text(`-es esetek nagy részét **kihagyta** — mérve 564 literál a valós ~700
 * helyett.)
 *
 * 1. nincs `$` interpoláció (a változós feliratok külön, kézi körben mennek),
 * 2. nem technikai (lásd `looksTechnical`),
 * 3. magyar ékezet VAGY szóköz VAGY **nagybetűs egyszó** van benne — így a
 *    `'Hiba'`, `'Vissza'`, `'Igen'` is bejön, a `'home'`, `'news'`,
 *    `'live_feed_posts'` azonosítók viszont nem,
 * 4. UI-környezetben áll (Text/… vagy ismert felirat-paraméter).
 */
export function isTranslationTarget({ value, before }) {
  if (value.includes('$')) return false;
  // A MÁR bekötött szöveg mindenképp kulcs (`tr(context, …)` / `trArgs(…)`):
  // a technikai heurisztika itt nem szűrhet, különben egy sablon (pl.
  // `'Beküldés #{id}'`, amiben `#` van) kiesne a szótár-ellenőrzésből — mérve
  // pontosan ez történt, és a kulcs „szótáron kívüliként" jelent meg.
  if (isWrappedContext(before)) return true;
  // ⚠️ Escape-elt literal (`\n`, `\'`, `\"`) kimarad: a szótár kulcsa a **valós**
  // szöveg, a forrásban viszont escape-ek vannak — ilyenkor a kulcs és a futásidejű
  // szöveg nem egyezne, és a fordítás csendben nem érvényesülne. Mérve a jelenlegi
  // 589 kulcs egyikében sincs escape, ezért ez a védelem nem szűkít.
  if (/\\./.test(value)) return false;
  if (looksTechnical(value)) return false;
  const trimmed = value.trim();
  const hasAccent = HUNGARIAN_LETTERS.test(trimmed);
  const hasSpace = /\s/.test(trimmed);
  const isCapitalizedWord = /^[A-ZÁÉÍÓÖŐÚÜŰ][a-záéíóöőúüű]+$/.test(trimmed);
  if (!hasAccent && !hasSpace && !isCapitalizedWord) return false;
  return isUiContext(before);
}

/** UI-környezet: `Text(`/`SelectableText(`/`AppText(` vagy ismert felirat-paraméter. */
export function isUiContext(before) {
  if (/(?:^|[\s(,{[])(?:Text|SelectableText|AppText)\s*\(\s*$/.test(before)) return true;
  return UI_NAMED_PARAMS.some((name) => new RegExp(`\\b${name}\\s*:\\s*$`).test(before));
}

/**
 * Már körbefordított szöveg: `tr(context, '…')` vagy `trArgs(context, '…')`.
 *
 * EZ A KULCS-SZÁMLÁLÁSHOZ KELL: a bekötés után a szöveg körül már ott a hívás,
 * ezért a kontextus megszűnik „UI-kontextusnak" lenni. Ha az extraktor nem
 * ismerné fel, a szótár-lefedettség mérése **hamisan** 21 szövegre esne vissza
 * (mérve pontosan ez történt), és a fordítatlan kulcsok észrevétlenek maradnának.
 */
export function isWrappedContext(before) {
  return /\btr(?:Args)?\(\s*context\s*,\s*$/.test(before);
}

export const UI_NAMED_PARAMS = [
  'label',
  'tooltip',
  'hintText',
  'labelText',
  'helperText',
  'errorText',
  'semanticLabel',
  'message',
  'title',
  'subtitle',
  'description',
  'content',
  'counterText',
  'prefixText',
  'suffixText',
];

/** A `tr(context, …)` hívás, amivé a literal alakul. */
export function wrapExpression(value) {
  return `tr(context, ${JSON.stringify(value)})`;
}

/** UI-réteg: a felület fájljai (itt a szövegek többsége megjelenik). */
export function isUiLayerFile(file) {
  return file.startsWith('lib/screens/') || file.startsWith('lib/widgets/');
}

/**
 * UI-réteg szövege — a szabályalapú célokon **túl**.
 *
 * MIÉRT KELL: a felület szövegei nem csak `Text('…')`/`label:` alakban élnek.
 * Vannak **ternary-ágban** (`cond ? 'A' : 'B'`), **argumentumban**, **lista- vagy
 * térkép-értékben**, és ezeket az első kör szabálya nem látta (mérve: **468**
 * valódi rés a UI-rétegben).
 *
 * ⚠️ AMIT SZÁNDÉKOSAN KIZÁR: a **térkép-kulcsot** (`'X': value`), az
 * **összehasonlítást/case-t** (`== 'X'`), az **értékadást** (`= 'X'` — lehet
 * kereső kulcs) és a `return`-t (a hívó dönti el). Ezeknél a szöveg fordítás
 * helyett **azonosító** lehet, ezért kézi döntés kell.
 */
export function isUiLayerTarget({ value, before, after }) {
  if (value.includes('$')) return false;
  if (/\\./.test(value)) return false;
  if (looksTechnical(value)) return false;
  const trimmed = value.trim();
  const hasAccent = HUNGARIAN_LETTERS.test(trimmed);
  const hasSpace = /\s/.test(trimmed);
  const isCapitalizedWord = /^[A-ZÁÉÍÓÖŐÚÜŰ][a-záéíóöőúüű]+$/.test(trimmed);
  if (!hasAccent && !hasSpace && !isCapitalizedWord) return false;
  if (/^\s*:/.test(after ?? '')) return false;
  if (/[=!]=\s*$/.test(before) || /\bcase\s+$/.test(before)) return false;
  if (/=\s*$/.test(before)) return false;
  if (/\breturn\s*$/.test(before)) return false;
  return true;
}

/** Minden `lib/**\/*.dart` fájl. */
export function dartFiles(root = 'lib') {
  const files = [];
  (function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith('.dart')) files.push(full.replaceAll('\\', '/'));
    }
  })(root);
  return files;
}

/** A literal-ok megkeresése egy sorban (idézőjel-párok, escape-ek kezelve). */
export function stringLiterals(line) {
  const found = [];
  const pattern = /'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)"/g;
  let match;
  while ((match = pattern.exec(line)) !== null) {
    found.push({
      value: match[1] ?? match[2] ?? '',
      quote: match[1] !== undefined ? "'" : '"',
      start: match.index,
      end: match.index + match[0].length,
      raw: match[0],
    });
  }
  return found;
}

#!/usr/bin/env node
/**
 * Mutációs bizonyíték a **@mindenki PUSH**-ra — a tulajdonos jelzése:
 * *„ja a @mindenki tag nem működik, nem küld notifyt"* (az éles mérés szerint a
 * bejövő listabeli értesítések létrejöttek, push viszont nem ment; a döntése:
 * a @mindenki kapjon push-t, a személyes @említés maradjon csendes).
 *
 * Minden mutáció egy VALÓDI hiba-visszaállítás (a javítás elvétele), és
 * mindegyiknek BUKNIA kell a teszten. A visszaállítás **bájtazonos** (SHA-256-tal
 * igazolva), és a végén a helyreállított kör **újra zöld**.
 *
 * ⚠️ A „nem futott le" nem bizonyíték: a spawn-hibát (pl. `flutter` `.bat`)
 * megkülönböztetjük a valódi tesztbukástól — ez a hiba már kétszer félrevezetett.
 */
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';

const SERVER = 'functions/index.js';
const PLAN = 'functions/chat-mention-plan.js';
const SERVER_TEST = 'functions/chat-mention-plan.test.cjs';
const CHAT_PUSH_TEST = 'functions/chat-notification-plan.test.cjs';
const DART_TEST = 'test/services/chat_mention_wiring_test.dart';

const sha = (text) => crypto.createHash('sha256').update(text, 'utf8').digest('hex');

function runCommand(command) {
  try {
    execSync(command, { stdio: 'pipe', encoding: 'utf8' });
    return { ok: true, output: '' };
  } catch (error) {
    if (error.status === undefined || error.status === null) {
      throw new Error(`a parancs nem futott le (spawn-hiba): ${error.message}`);
    }
    return { ok: false, output: `${error.stdout ?? ''}${error.stderr ?? ''}` };
  }
}

const runners = {
  server: () => runCommand(`node --test ${SERVER_TEST} ${CHAT_PUSH_TEST}`),
  dart: () => runCommand(`flutter test ${DART_TEST}`),
};

/** A fájl saját sorvége (a fájlok CRLF-esek — a `\n`-es horgony „nem találna"). */
const eolOf = (source) => (source.includes('\r\n') ? '\r\n' : '\n');

const mutations = [
  {
    label: 'a szerver NEM küldi el a @mindenki push-t (a hívás elvéve)',
    file: SERVER,
    runner: 'server',
    // ⚠️ A fájl CRLF-es: a horgonyt a fájl saját sorvégével kell összerakni,
    // különben a mutáció „nem talál" — és a bizonyíték HAMIS képet ad.
    transform: (source) =>
      source.replace(
        `const result = await sendMulticastToAllTokens(${eolOf(source)}`,
        `const result = await skipPush(${eolOf(source)}`,
      ),
  },
  {
    label: 'a push a RÉGI értesítésre is elmegy (nincs `created` kapu)',
    file: PLAN,
    runner: 'server',
    transform: (source) => source.replace('    if (entry.created !== true) continue;', ''),
  },
  {
    label: 'a kikapcsolt értesítés is kap push-t (a preferences-kapu elvéve)',
    file: PLAN,
    runner: 'server',
    transform: (source) =>
      source.replace("    if (preferences.enabled === false) continue;", ''),
  },
  {
    label: 'a token nélküli címzett is bekerül a push-célpontok közé',
    file: PLAN,
    runner: 'server',
    transform: (source) => source.replace('    if (!tokens.length) continue;', ''),
  },
  {
    label: 'a push-hoz tartozó katalógus-cím elvéve (nyelv helyett fix magyar)',
    file: SERVER,
    runner: 'server',
    transform: (source) =>
      source.replace(
        "notificationText('chat_everyone', language, {",
        "notificationText('chat_everyone', 'hu', {",
      ).replace(
        "const language = await recipientLanguage(target.uid);",
        "const language = 'hu';",
      ),
  },
  {
    label: 'a válasz visszaadott számából kimarad a push (`everyonePushed`)',
    file: SERVER,
    runner: 'server',
    transform: (source) =>
      source.replace(
        'return { id: ref.id, droppedMentions, everyoneNotified, everyonePushed };',
        'return { id: ref.id, droppedMentions, everyoneNotified };',
      ),
  },
  {
    label: 'a kliens NEM jelzi vissza a küldőnek a fan-out méretét',
    file: 'lib/screens/community/community_screen.dart',
    runner: 'dart',
    transform: (source) => source.replace('if (result.everyoneNotified > 0) {', 'if (false) {'),
  },
  {
    label: 'a @mindenki push koppintása nem nyitja meg a Chatet (az ág elvéve)',
    file: 'lib/services/push_notification_service.dart',
    runner: 'dart',
    transform: (source) =>
      source.replace(
        "      if (type == 'chat_everyone' || type == 'chat_mention') {",
        "      if (false) {",
      ),
  },
  {
    label: 'a fölértesítés nem lesz koppintható (@mindenki kivéve a `_hasOpenTarget`-ből)',
    file: 'lib/services/push_notification_service.dart',
    runner: 'dart',
    transform: (source) => {
      const eol = eolOf(source);
      return source.replace(
        `        ((type == 'chat_everyone' || type == 'chat_mention') &&${eol}            chatPostId.isNotEmpty) ||`,
        '',
      );
    },
  },
  {
    label: 'a szerver visszajelzése elvész: a szolgáltatás nem olvassa a számokat',
    file: 'lib/services/community_service.dart',
    runner: 'dart',
    transform: (source) =>
      source.replace("      final pushed = data['everyonePushed'];", '      final pushed = 0;'),
  },
];

let caught = 0;
const results = [];

for (const mutation of mutations) {
  const original = fs.readFileSync(mutation.file, 'utf8');
  const originalHash = sha(original);
  const mutated = mutation.transform(original);
  if (mutated === original) {
    results.push(`HIBA  ${mutation.label} — a mutáció nem változtatott semmit (a horgony elavult?)`);
    continue;
  }

  fs.writeFileSync(mutation.file, mutated, 'utf8');
  const outcome = runners[mutation.runner]();
  fs.writeFileSync(mutation.file, original, 'utf8');
  const restored = sha(fs.readFileSync(mutation.file, 'utf8')) === originalHash;

  if (!restored) {
    results.push(`HIBA  ${mutation.label} — a visszaállítás NEM bájtazonos`);
    continue;
  }
  if (outcome.ok) {
    results.push(`NEM KAPTA EL  ${mutation.label}`);
  } else {
    caught += 1;
    results.push(`ELKAPVA  ${mutation.label}`);
  }
}

console.log(results.join('\n'));
console.log(`\n${caught}/${mutations.length} mutáció elkapva`);

const finalServer = runners.server();
const finalDart = runners.dart();
const green = finalServer.ok && finalDart.ok;
console.log(
  green
    ? 'a helyreállított kör ÚJRA ZÖLD (szerver + kliens)'
    : `HIBA: a helyreállított kör sem zöld:\n${(finalServer.output + finalDart.output).slice(-600)}`,
);
process.exitCode = caught === mutations.length && green ? 0 : 1;
